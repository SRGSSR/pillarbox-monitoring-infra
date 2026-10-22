# -----------------------------------
# Security Group for Quanthea ALB
# -----------------------------------

resource "aws_security_group" "quanthea_alb_sg" {
  count = local.is_prod ? 1 : 0

  name   = "quanthea-alb-sg"
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
    Name = "quanthea-alb-sg"
  }
}

# -----------------------------------
# Application Load Balancer for Quanthea
# -----------------------------------

resource "aws_alb" "quanthea_alb" {
  count = local.is_prod ? 1 : 0

  name                             = "quanthea-alb"
  subnets                          = data.aws_subnets.public_subnets.ids
  security_groups                  = [aws_security_group.quanthea_alb_sg[0].id]
  enable_cross_zone_load_balancing = true
  idle_timeout                     = 300 # Quanthea streams its answers as server-sent events

  tags = {
    Name = "quanthea-alb"
  }
}

# -----------------------------------
# Target Group for Quanthea
# -----------------------------------

resource "aws_alb_target_group" "quanthea_alb_tg" {
  count = local.is_prod ? 1 : 0

  name        = "quanthea-alb-tg"
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
    Name = "quanthea-alb-tg"
  }
}

resource "aws_alb_target_group_attachment" "quanthea_group_attachment" {
  count = local.is_prod ? 1 : 0

  target_group_arn = aws_alb_target_group.quanthea_alb_tg[0].arn
  target_id        = aws_instance.quanthea[0].private_ip
  port             = 3000
}

# -----------------------------------
# ACM Certificate for Quanthea
# -----------------------------------

# ACM Certificate for quanthea service, validated via DNS
resource "aws_acm_certificate" "quanthea_certificate" {
  count = local.is_prod ? 1 : 0

  domain_name       = local.quanthea.domain_name
  validation_method = "DNS"

  tags = {
    Name = "quanthea-acm-cert"
  }
}

# Wait for the certificate to be issued before attaching it to the listener
resource "aws_acm_certificate_validation" "quanthea_certificate_validation" {
  count = local.is_prod ? 1 : 0

  certificate_arn         = aws_acm_certificate.quanthea_certificate[0].arn
  validation_record_fqdns = [for record in aws_route53_record.quanthea_cert_validation : record.fqdn]
}

# -----------------------------------
# Route 53 DNS Records for Quanthea ALB
# -----------------------------------

# DNS record for quanthea ALB
resource "aws_route53_record" "quanthea_alb_dns" {
  count = local.is_prod ? 1 : 0

  provider = aws.prod
  zone_id  = data.aws_route53_zone.main_zone.zone_id
  name     = local.quanthea.domain_name
  type     = "A"

  alias {
    name                   = aws_alb.quanthea_alb[0].dns_name
    zone_id                = aws_alb.quanthea_alb[0].zone_id
    evaluate_target_health = true
  }
}

# DNS record for ACM certificate validation
resource "aws_route53_record" "quanthea_cert_validation" {
  provider = aws.prod
  for_each = {
    for dvo in flatten(aws_acm_certificate.quanthea_certificate[*].domain_validation_options) : dvo.domain_name => {
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
# ALB Listeners for Quanthea
# -----------------------------------

# HTTP Listener to redirect traffic to HTTPS
resource "aws_alb_listener" "quanthea_http_listener" {
  count = local.is_prod ? 1 : 0

  load_balancer_arn = aws_alb.quanthea_alb[0].arn
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
    Name = "quanthea-http-listener"
  }
}

# HTTPS Listener for the ALB
resource "aws_alb_listener" "quanthea_listener" {
  count = local.is_prod ? 1 : 0

  load_balancer_arn = aws_alb.quanthea_alb[0].arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate_validation.quanthea_certificate_validation[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.quanthea_alb_tg[0].arn
  }

  tags = {
    Name = "quanthea-https-listener"
  }
}

# -----------------------------------
# Security Group for Quanthea Instance
# -----------------------------------

resource "aws_security_group" "quanthea_sg" {
  count = local.is_prod ? 1 : 0

  name   = "quanthea-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Allow HTTP access from ALB
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
    security_groups = [data.aws_security_group.bastion_sg.id]
  }

  tags = {
    Name = "quanthea-sg"
  }
}

# -----------------------------------
# Quanthea EC2 Instance
# -----------------------------------

resource "aws_instance" "quanthea" {
  count = local.is_prod ? 1 : 0

  ami                         = local.quanthea.ami
  instance_type               = local.quanthea.instance_type
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  vpc_security_group_ids      = [aws_security_group.quanthea_sg[0].id]
  key_name                    = "bastion-keypair"
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.quanthea_instance_profile[0].name

  # Install Docker and run quanthea with its configuration file
  user_data = <<-EOF
              #!/bin/bash
              set -e  # Exit on error

              sudo yum update -y
              sudo yum install -y aws-cli docker
              sudo systemctl enable --now docker

              sudo install -d -m 700 /etc/quanthea

              # Configuration file, see https://quanthea.ch/docs/configuration/
              cat <<'EOT' | sudo tee /etc/quanthea/quanthea.yaml
              server:
                publicUrl: https://${local.quanthea.domain_name}
                trustedProxyHops: 1
                logFormat: json

              users:
                admin:
                  password: $${ADMIN_PASSWORD}

              connectors:
                opensearch:
                  kind: opensearch
                  config:
                    url: http://${aws_instance.opensearch.private_ip}:9200
                    auth: none
              EOT

              # Secrets the configuration file refers to
              QUANTHEA_PWD=$(aws ssm get-parameter --region "${data.aws_region.current.name}" --name "/quanthea/admin_password" --with-decryption --query "Parameter.Value" --output text)
              (umask 077 && printf 'ADMIN_PASSWORD=%s\n' "$QUANTHEA_PWD" | sudo tee /etc/quanthea/quanthea.env > /dev/null)

              sudo docker run -d --name quanthea --restart unless-stopped \
                -p 3000:3000 \
                -v quanthea-data:/data \
                -v quanthea-keys:/keys \
                -v /etc/quanthea/quanthea.yaml:/etc/quanthea/quanthea.yaml:ro \
                --env-file /etc/quanthea/quanthea.env \
                ${local.quanthea.image}
              EOF

  # The user data reads the admin password at first boot
  depends_on = [
    aws_ssm_parameter.quanthea_admin_password,
    aws_iam_role_policy_attachment.quanthea_ssm_policy_attach,
  ]

  tags = {
    Name = "quanthea-instance"
  }
}

resource "aws_ssm_parameter" "quanthea_admin_password" {
  count = local.is_prod ? 1 : 0

  name        = "/quanthea/admin_password"
  description = "Quanthea admin password"
  type        = "SecureString"
  value       = var.quanthea_default_pwd

  tags = {
    Name = "quanthea-admin-password"
  }
}
