# -----------------------------------
# OpenSearch EC2 Instance
# -----------------------------------

resource "aws_security_group" "opensearch_sg" {
  name   = "opensearch-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Allow HTTPS from Grafana, Bastion and Data Transfer
  ingress {
    description = "Allow HTTP access from Grafana, Bastion and data transfer service"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    security_groups = [
      aws_security_group.transfer_task_sg.id,
      aws_security_group.grafana_sg.id,
      aws_security_group.bastion_sg.id
    ]
  }

  # Allow SSH from Bastion
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Egress: allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "opensearch-sg"
  }
}

# -----------------------------------
# OpenSearch EC2 Instance
# -----------------------------------

resource "aws_instance" "opensearch" {
  ami                         = local.opensearch.ami
  instance_type               = local.opensearch.instance_type
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  vpc_security_group_ids      = [aws_security_group.opensearch_sg.id]
  key_name                    = "bastion-keypair"
  ebs_optimized               = true
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.opensearch_instance_profile.name

  # Mount the attached EBS volume and install OpenSearch
  user_data = <<-EOF
              #!/bin/bash
              set -e  # Exit on errorx

              sudo yum update -y
              sudo yum install -y aws-cli

              sudo curl -SL https://artifacts.opensearch.org/releases/bundle/opensearch/3.x/opensearch-3.x.repo -o /etc/yum.repos.d/opensearch-3.x.repo
              sudo yum clean all
              sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD=$(aws ssm get-parameter --name "/opensearch/admin_password" --with-decryption --query "Parameter.Value" --output text) yum install -y opensearch

              {
                echo "plugins.security.disabled: true"
                echo "discovery.type: single-node"
                echo "network.host: 0.0.0.0"
                echo "node.name: opensearch-node"
                echo "bootstrap.memory_lock: true"
              } | sudo tee -a /etc/opensearch/opensearch.yml
              echo "${local.opensearch.java_opts}" | tr ' ' '\n' | sudo tee /etc/opensearch/jvm.options.d/custom.options

              sudo systemctl enable opensearch
              sudo systemctl start opensearch
              EOF

  root_block_device {
    volume_size = local.opensearch.volume.size
    volume_type = local.opensearch.volume.type
    throughput  = local.opensearch.volume.throughput
    iops        = local.opensearch.volume.iops
  }

  tags = {
    Name = "opensearch-instance"
  }
}

resource "aws_ssm_parameter" "opensearch_admin_password" {
  name        = "/opensearch/admin_password"
  description = "Opensearch admin password"
  type        = "SecureString"
  value       = var.opensearch_default_pwd

  tags = {
    Name = "opensearch-admin-password"
  }
}
