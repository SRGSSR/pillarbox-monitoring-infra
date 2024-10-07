# -----------------------------------
# Security Group for Dispatch ALB
# -----------------------------------

resource "aws_security_group" "dispatch_alb_sg" {
  name   = "dispatch-alb-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Allow HTTP access from the internet
  ingress {
    description = "Allow HTTP access from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS access from the internet
  ingress {
    description = "Allow HTTPS access from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dispatch-alb-sg"
  }
}

# -----------------------------------
# Application Load Balancer for Dispatch
# -----------------------------------

resource "aws_alb" "dispatch_alb" {
  name                             = "dispatch-alb"
  subnets                          = data.aws_subnets.public_subnets.ids
  security_groups                  = [aws_security_group.dispatch_alb_sg.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "dispatch-alb"
  }
}

# -----------------------------------
# Target Group for Dispatch
# -----------------------------------

## Target Group for dispatch service to route traffic to ECS tasks

resource "aws_alb_target_group" "dispatch_alb_tg" {
  name        = "dispatch-alb-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.main_vpc.id

  # Health check configuration for the target group
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/health"
  }

  tags = {
    Name = "dispatch-alb-tg"
  }
}

# -----------------------------------
# ACM Certificate for Dispatch
# -----------------------------------

# ACM Certificate for dispatch service, validated via DNS
resource "aws_acm_certificate" "dispatch_certificate" {
  domain_name       = local.domain_name
  validation_method = "DNS"

  tags = {
    Name = "dispatch-acm-cert"
  }
}

# -----------------------------------
# Route 53 DNS Records for Dispatch ALB
# -----------------------------------

## Route 53 zone data lookup for DNS management

data "aws_route53_zone" "main_zone" {
  provider = aws.prod
  name     = var.pillarbox_domain_name
}

# DNS record for dispatch ALB
resource "aws_route53_record" "dispatch_alb_dns" {
  provider = aws.prod
  zone_id  = data.aws_route53_zone.main_zone.zone_id
  name     = local.domain_name
  type     = "A"

  alias {
    name                   = aws_alb.dispatch_alb.dns_name
    zone_id                = aws_alb.dispatch_alb.zone_id
    evaluate_target_health = true
  }
}

# DNS record for ACM certificate validation
resource "aws_route53_record" "dispatch_cert_validation" {
  provider = aws.prod
  for_each = {
    for dvo in aws_acm_certificate.dispatch_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main_zone.zone_id
}

# -----------------------------------
# ALB Listeners for Dispatch
# -----------------------------------

# HTTP Listener to redirect traffic to HTTPS
resource "aws_alb_listener" "dispatch_http_listener" {
  load_balancer_arn = aws_alb.dispatch_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301" # Permanent redirect
    }
  }

  tags = {
    Name = "dispatch-http-listener"
  }
}

# HTTPS Listener for the ALB
resource "aws_alb_listener" "dispatch_listener" {
  load_balancer_arn = aws_alb.dispatch_alb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate.dispatch_certificate.arn

  # Default action returns 403 Forbidden for unmatched requests
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "403 Forbidden"
      status_code  = "403"
    }
  }

  tags = {
    Name = "dispatch-https-listener"
  }
}

# Listener Rule to forward requests to the API
resource "aws_alb_listener_rule" "allow_api_rule" {
  listener_arn = aws_alb_listener.dispatch_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.dispatch_alb_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = {
    Name = "dispatch-https-allow-api-rule"
  }
}

# -----------------------------------
# Security Group for Dispatch ECS Tasks
# -----------------------------------

## Security Group for dispatch ECS tasks to allow access from ALB

resource "aws_security_group" "dispatch_task_sg" {
  name   = "dispatch-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Allow HTTP access from ALB and transfer service
  ingress {
    description = "Allow HTTP access from ALB and transfer service"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [
      aws_security_group.dispatch_alb_sg.id,
      aws_security_group.transfer_task_sg.id
    ]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dispatch-sg"
  }
}

# -----------------------------------
# CloudWatch Log Group for Dispatch
# -----------------------------------

resource "aws_cloudwatch_log_group" "dispatch_log_group" {
  name              = "/ecs/pillarbox-event-dispatcher"
  retention_in_days = 7 # Adjust the retention as needed

  tags = {
    Name = "dispatch-log-group"
  }
}

# -----------------------------------
# ECS Task Definition for Dispatch
# -----------------------------------

resource "aws_ecs_task_definition" "dispatch_task" {
  family                   = "pillarbox-event-dispatcher"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.dispatch_task.cpu
  memory                   = local.dispatch_task.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # Container definition for the dispatch service
  container_definitions = jsonencode([
    {
      name                   = "pillarbox-event-dispatcher"
      image                  = "${local.ecr_repository}/pillarbox-event-dispatcher:latest"
      readonlyRootFilesystem = true

      portMappings = [
        {
          hostPort      = 8080
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = "8080"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.dispatch_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "dispatch-task"
  }
}

# -----------------------------------
# ECS Service for Dispatch
# -----------------------------------

## ECS Service for dispatch tasks, integrated with ALB and service discovery

resource "aws_ecs_service" "dispatch_service" {
  name            = "dispatch-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.dispatch_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Network configuration for Fargate tasks
  network_configuration {
    subnets         = [data.aws_subnets.private_subnets.ids[0]]
    security_groups = [aws_security_group.dispatch_task_sg.id]
  }

  # Load balancer integration with the ALB target group
  load_balancer {
    target_group_arn = aws_alb_target_group.dispatch_alb_tg.arn
    container_name   = "pillarbox-event-dispatcher"
    container_port   = 8080
  }

  # Service registry for DNS-based service discovery
  service_registries {
    registry_arn = aws_service_discovery_service.dispatch_service_discovery.arn
  }

  depends_on = [aws_alb_listener.dispatch_listener]
}

# -----------------------------------
# Service Discovery for Dispatch
# -----------------------------------

## Service Discovery for ECS tasks using private DNS

resource "aws_service_discovery_service" "dispatch_service_discovery" {
  name = "dispatch-service-discovery"

  # DNS configuration for service discovery
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_discovery_namespace.id

    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  # Custom health check configuration
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "dispatch-service"
  }
}
