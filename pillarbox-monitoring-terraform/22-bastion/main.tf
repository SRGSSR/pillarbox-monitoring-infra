# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "rts-digital-terraform-backends-53a0d15f"
    key            = "pillarbox-monitoring-infra/22-bastion.tfstate"
    dynamodb_table = "rts-digital-terraform-statelocks"
    profile        = "services-prd"
  }

  # Specify required providers and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.4.0"
    }
  }
}

# -----------------------------------
# AWS Provider Setup
# -----------------------------------

provider "aws" {
  # Apply default tags to all AWS resources
  default_tags {
    tags = local.default_tags
  }
}

# -----------------------------------
# AWS Data Sources
# -----------------------------------

# Retrieve the VPC information
data "aws_vpc" "main_vpc" {
  id = local.vpc_id
}

# Retrieve public subnets based on VPC and tags
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Name = "*public*"
  }
}

# -----------------------------------
# Bastion configuration
# -----------------------------------

resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-keypair"
  public_key = var.bastion_public_key
}

# Security Group for the Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH access by IP"
  vpc_id      = data.aws_vpc.main_vpc.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_ips
  }
}

# Bastion Host EC2 Instance in Public Subnet
resource "aws_instance" "bastion" {
  ami                         = local.bastion_ami
  instance_type               = local.bastion_instance_type
  subnet_id                   = data.aws_subnets.public_subnets.ids[0]
  key_name                    = "bastion-keypair"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}

# -----------------------------------
# OpenSearch security group rule
# -----------------------------------

data "aws_security_group" "opensearch_sg" {
  filter {
    name   = "group-name"
    values = ["opensearch-sg"]
  }
}

resource "aws_security_group_rule" "new_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = data.aws_security_group.opensearch_sg.id
}

# -----------------------------------
# Outputs
# -----------------------------------

output "bastion_public_ip" {
  description = "Public IP of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}
