# -----------------------------------
# IL Proxy Setup
# -----------------------------------

# EC2 Instance for the IL proxy
resource "aws_instance" "il_proxy" {
  ami                         = local.il_proxy.ami
  instance_type               = local.il_proxy.instance_type
  subnet_id                   = data.aws_subnets.public_subnets.ids[0] # Use a private subnet
  vpc_security_group_ids      = [aws_security_group.il_proxy_sg.id]
  associate_public_ip_address = true

  # Nginx setup
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y nginx

              sudo cat <<EOT > /etc/nginx/default.d/reverse-proxy.conf
              location / {
                  if (\$http_x_api_key != "${local.il_proxy.api_key}") {
                      return 403;
                  }

                  proxy_pass https://il.srgssr.ch; # Proxy to the external API
                  proxy_set_header Host il.srgssr.ch;
                  proxy_set_header X-Real-IP \$remote_addr;
                  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto \$scheme;
              }
              EOT

              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF

  tags = {
    Name = "il-proxy-instance"
  }
}

# Security Group for the IL proxy
resource "aws_security_group" "il_proxy_sg" {
  name   = "il-proxy-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Ingress rule: Allow inbound traffic from VPC
  ingress {
    description = "Allow inbound traffic from the VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "il-proxy-sg"
  }
}
