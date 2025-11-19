# -----------------------------------
# Security Group for Grafana ALB
# -----------------------------------

resource "aws_security_group" "grafana_alb_sg" {
  name   = "grafana-alb-sg"
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
    cidr_blocks = ["0.0.0.0/0"] # Adjust CIDR block to restrict access
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
    Name = "grafana-alb-sg"
  }
}

# -----------------------------------
# Application Load Balancer for Grafana
# -----------------------------------

resource "aws_alb" "grafana_alb" {
  name                             = "grafana-alb"
  subnets                          = data.aws_subnets.public_subnets.ids
  security_groups                  = [aws_security_group.grafana_alb_sg.id]
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "grafana-alb"
  }
}

# -----------------------------------
# Target Group for Grafana
# -----------------------------------

## Target Group for grafana service

resource "aws_alb_target_group" "grafana_alb_tg" {
  name        = "grafana-alb-tg"
  port        = 3000
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
    path                = "/api/health"
  }

  tags = {
    Name = "grafana-alb-tg"
  }
}

resource "aws_alb_target_group_attachment" "grafana_group_attachment" {
  target_group_arn = aws_alb_target_group.grafana_alb_tg.arn
  target_id        = aws_instance.grafana.private_ip
  port             = 3000
}

# -----------------------------------
# ACM Certificate for Grafana
# -----------------------------------

# ACM Certificate for grafana service, validated via DNS
resource "aws_acm_certificate" "grafana_certificate" {
  domain_name       = local.grafana.domain_name
  validation_method = "DNS"

  tags = {
    Name = "grafana-acm-cert"
  }
}

# -----------------------------------
# Route 53 DNS Records for Grafana ALB
# -----------------------------------

# DNS record for grafana ALB
resource "aws_route53_record" "grafana_alb_dns" {
  provider = aws.prod
  zone_id  = data.aws_route53_zone.main_zone.zone_id
  name     = local.grafana.domain_name
  type     = "A"

  alias {
    name                   = aws_alb.grafana_alb.dns_name
    zone_id                = aws_alb.grafana_alb.zone_id
    evaluate_target_health = true
  }
}

# DNS record for ACM certificate validation
resource "aws_route53_record" "grafana_cert_validation" {
  provider = aws.prod
  for_each = {
    for dvo in aws_acm_certificate.grafana_certificate.domain_validation_options : dvo.domain_name => {
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
# ALB Listeners for Grafana
# -----------------------------------

# HTTP Listener to redirect traffic to HTTPS
resource "aws_alb_listener" "grafana_http_listener" {
  load_balancer_arn = aws_alb.grafana_alb.arn
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
    Name = "grafana-http-listener"
  }
}

# HTTPS Listener for the ALB
resource "aws_alb_listener" "grafana_listener" {
  load_balancer_arn = aws_alb.grafana_alb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate.grafana_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.grafana_alb_tg.arn
  }

  tags = {
    Name = "grafana-https-listener"
  }
}

# -----------------------------------
# Security Group for Grafana ECS Tasks
# -----------------------------------

## Security Group for grafana ECS tasks to allow access from ALB

resource "aws_security_group" "grafana_sg" {
  name   = "grafana-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Allow HTTP access from ALB and transfer service
  ingress {
    description = "Allow HTTP access from ALB"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main_vpc.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from the Bastion host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  tags = {
    Name = "grafana-sg"
  }
}

# -----------------------------------
# AWS Grafana Workspace Setup
# -----------------------------------

resource "aws_instance" "grafana" {
  ami                         = local.grafana.ami
  instance_type               = local.grafana.instance_type
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  vpc_security_group_ids      = [aws_security_group.grafana_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.grafana_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              set -e  # Exit on error

              sudo yum update -y
              sudo yum install -y aws-cli

              wget -q -O gpg.key https://rpm.grafana.com/gpg.key
              sudo rpm --import gpg.key
              sudo rm gpg.key

              # Add Grafana repo
              cat <<EOT | sudo tee /etc/yum.repos.d/grafana.repo
              [grafana]
              name=grafana
              baseurl=https://rpm.grafana.com
              repo_gpgcheck=1
              enabled=1
              gpgcheck=1
              gpgkey=https://rpm.grafana.com/gpg.key
              sslverify=1
              sslcacert=/etc/pki/tls/certs/ca-bundle.crt
              EOT

              # Install Grafana
              sudo yum install -y grafana

              cat <<EOT | sudo tee /etc/grafana/grafana.ini
              [server]
              domain = ${local.grafana.domain_name}
              root_url = https://%(domain)s/
              EOT

              # Start Grafana service
              sudo systemctl enable --now grafana-server

              # Set admin password securely using Grafana CLI
              GRAFANA_PWD=$(aws ssm get-parameter --name "/grafana/admin_password" --with-decryption --query "Parameter.Value" --output text)
              sudo grafana-cli admin reset-admin-password "$GRAFANA_PWD"
              EOF


  tags = {
    Name = "grafana-instance"
  }
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name        = "/grafana/admin_password"
  description = "Grafana admin password"
  type        = "SecureString"
  value       = var.grafana_default_pwd

  tags = {
    Name = "grafana-admin-password"
  }
}
