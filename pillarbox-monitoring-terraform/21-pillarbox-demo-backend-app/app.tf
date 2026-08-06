# -----------------------------------
# Security Group for Service ALB
# -----------------------------------

resource "aws_security_group" "demo_backend_alb_sg" {
  name   = "demo-backend-alb-sg"
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
    Name = "demo-backend-alb-sg"
  }
}

# -----------------------------------
# Application Load Balancer for Demo Backend
# -----------------------------------

resource "aws_alb" "demo_backend_alb" {
  name                             = "demo-backend-alb"
  subnets                          = data.aws_subnets.public_subnets.ids
  security_groups                  = [aws_security_group.demo_backend_alb_sg.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "demo-backend-alb"
  }
}

# -----------------------------------
# Target Group for Demo Backend
# -----------------------------------

## Target Group for demo backend service to route traffic to ECS tasks
resource "aws_alb_target_group" "demo_backend_alb_tg" {
  name        = "demo-backend-alb-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.main_vpc.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/v1/player/media"
  }

  tags = {
    Name = "demo-backend-alb-tg"
  }
}

# -----------------------------------
# ACM Certificate for Demo Backend
# -----------------------------------

# ACM Certificate for the backend service, validated via DNS
resource "aws_acm_certificate" "demo_backend_certificate" {
  domain_name       = local.demo-backend.domain_name
  validation_method = "DNS"

  tags = {
    Name = "demo-backend-acm-cert"
  }
}

# -----------------------------------
# Route 53 DNS Records for Demo Backend ALB
# -----------------------------------

# DNS record for the demo backend ALB
resource "aws_route53_record" "demo_backend_alb_dns" {
  provider = aws.prod
  zone_id  = data.aws_route53_zone.main_zone.zone_id
  name     = local.demo-backend.domain_name
  type     = "A"

  alias {
    name                   = aws_alb.demo_backend_alb.dns_name
    zone_id                = aws_alb.demo_backend_alb.zone_id
    evaluate_target_health = true
    # TODO Revert to evaluate_target_health = true
  }
}

# DNS record for ACM certificate validation
resource "aws_route53_record" "demo_backend_cert_validation" {
  provider = aws.prod
  for_each = {
    for dvo in aws_acm_certificate.demo_backend_certificate.domain_validation_options : dvo.domain_name => {
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
# ALB Listeners for Demo Backend
# -----------------------------------

# HTTP Listener to redirect traffic to HTTPS
resource "aws_alb_listener" "demo_backend_http_listener" {
  load_balancer_arn = aws_alb.demo_backend_alb.arn
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
    Name = "demo-backend-http-listener"
  }
}

# HTTPS Listener for the ALB
resource "aws_alb_listener" "demo_backend_listener" {
  load_balancer_arn = aws_alb.demo_backend_alb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate.demo_backend_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.demo_backend_alb_tg.arn
  }

  tags = {
    Name = "demo-backend-https-listener"
  }
}

# -----------------------------------
# Security Group for Demo Backend ECS Tasks
# -----------------------------------

## Security Group for the demo backend ECS tasks to allow access from ALB

resource "aws_security_group" "demo_backend_task_sg" {
  name   = "demo-backend-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Allow HTTP access from the ALB
  ingress {
    description     = "Allow HTTP access from the ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.demo_backend_alb_sg.id]
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
    Name = "demo-backend-sg"
  }
}

# -----------------------------------
# CloudWatch Log Group for Demo Backend
# -----------------------------------

resource "aws_cloudwatch_log_group" "demo_backend_log_group" {
  name              = "/ecs/pillarbox-demo-backend"
  retention_in_days = 7

  tags = {
    Name = "demo-backend-log-group"
  }
}

# -----------------------------------
# ECS Task Definition for Demo Backend
# -----------------------------------

resource "aws_ecs_task_definition" "demo_backend_task" {
  family                   = "pillarbox-demo-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.demo-backend.task.cpu
  memory                   = local.demo-backend.task.memory
  execution_role_arn       = aws_iam_role.demo_backend_ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.demo_backend_ecs_task_role.arn

  # Container definition for the demo backend service
  container_definitions = jsonencode([
    {
      name                   = "pillarbox-demo-backend"
      image                  = "${local.ecr_repository}/pillarbox-demo-backend:${local.ecr_image_tag}"
      readonlyRootFilesystem = true

      portMappings = [
        {
          hostPort      = 8080
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENABLE_FORWARDED_HEADERS", value = "true" },
        { name = "DATABASE_URL", value = "jdbc:postgresql://${aws_db_instance.demo_backend_postgresql.address}:${aws_db_instance.demo_backend_postgresql.port}/${aws_db_instance.demo_backend_postgresql.db_name}" },
        { name = "DATABASE_USER", value = local.postgresql.username },
        { name = "AUTH_ISSUER", value = local.auth_issuer },
        { name = "AUTH_CLIENT_ID", value = local.auth_client_id },
        { name = "AUTH_SCOPES", value = local.auth_scopes },
      ]

      # Sensitive Variables (Secrets)
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = aws_ssm_parameter.postgresql_admin_password.arn
        },
        {
          name      = "SESSION_COOKIE_SECRET"
          valueFrom = aws_ssm_parameter.session_cookie_secret.arn
        },
        {
          name      = "AUTH_CLIENT_SECRET"
          valueFrom = aws_ssm_parameter.auth_client_secret.arn
        },
        {
          name      = "DATABASE_ENCRYPTION_KEY"
          valueFrom = aws_ssm_parameter.database_encryption_key.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.demo_backend_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "demo-backend-task"
  }
}

# -----------------------------------
# ECS Service for Demo Backend
# -----------------------------------

## ECS Service for the demo backend tasks, integrated with ALB and service discovery

resource "aws_ecs_service" "demo_backend_service" {
  name            = "demo-backend-service"
  cluster         = aws_ecs_cluster.demo_backend_ecs_cluster.id
  task_definition = aws_ecs_task_definition.demo_backend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Network configuration for Fargate tasks
  network_configuration {
    subnets          = [data.aws_subnets.public_subnets.ids[0]]
    security_groups  = [aws_security_group.demo_backend_task_sg.id]
    assign_public_ip = true
  }

  # Load balancer integration with the ALB target group
  load_balancer {
    target_group_arn = aws_alb_target_group.demo_backend_alb_tg.arn
    container_name   = "pillarbox-demo-backend"
    container_port   = 8080
  }

  depends_on = [aws_alb_listener.demo_backend_listener]
}


resource "aws_ssm_parameter" "session_cookie_secret" {
  name        = "/demo-backend/session_cookie_secret"
  description = "Session Cookie Secret"
  type        = "SecureString"
  value       = local.session_cookie_secret

  tags = {
    Name = "demo-backend-session-cookie-secret"
  }
}


resource "aws_ssm_parameter" "auth_client_secret" {
  name        = "/demo-backend/auth_client_secret"
  description = "Auth Client Secret"
  type        = "SecureString"
  value       = local.auth_client_secret

  tags = {
    Name = "demo-backend-auth-client-secret"
  }
}


resource "aws_ssm_parameter" "database_encryption_key" {
  name        = "/demo-backend/database_encryption_key"
  description = "Database Encryption Ley"
  type        = "SecureString"
  value       = local.database_encryption_key

  tags = {
    Name = "demo-backend-database-encryption-key"
  }
}


