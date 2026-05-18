# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "rts-digital-terraform-backends-53a0d15f"
    key            = "pillarbox-monitoring-infra/22-pillarbox-demo-backend-app.tfstate"
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
  allowed_account_ids = [local.account_id]

  # Apply default tags to all AWS resources
  default_tags {
    tags = local.default_tags
  }
}

# Provider to access the production account with assumed role
provider "aws" {
  alias               = "prod"
  allowed_account_ids = [var.account_ids["prod"]]

  dynamic "assume_role" {
    for_each = local.is_prod ? [] : [1]
    content {
      role_arn = "arn:aws:iam::${var.account_ids["prod"]}:role/route53-access-role"
    }
  }
}

# -----------------------------------
# AWS Data Sources
# -----------------------------------

# Get current AWS region
data "aws_region" "current" {}

# Retrieve the VPC information
data "aws_vpc" "main_vpc" {
  id = local.vpc_id
}

# Retrieve private subnets based on VPC and tags
data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Name = "*private*"
  }
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
# AWS Route 53 zone data lookup
# -----------------------------------

data "aws_route53_zone" "main_zone" {
  provider = aws.prod
  name     = var.pillarbox_domain_name
}

# -----------------------------------
# AWS ECS Cluster creation
# -----------------------------------

# Create ECS Cluster
resource "aws_ecs_cluster" "demo_backend_ecs_cluster" {
  name = local.ecs_cluster_name
}

# -----------------------------------
# AWS VPC Endpoints Setup
# -----------------------------------

# 1. Find the existing Security Group from the 20-pillarbox-monitoring-app project
data "aws_security_group" "shared_vpc_endpoints_sg" {
  filter {
    name   = "tag:Name"
    values = ["vpc-endpoints-sg"]
  }
}

# 2. Add the new Backend Task SG as an authorized source
resource "aws_security_group_rule" "allow_backend_to_shared_endpoints" {
  type        = "ingress"
  description = "Allow demo-backend to access ECR/Logs/SSM via shared endpoints"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"

  security_group_id        = data.aws_security_group.shared_vpc_endpoints_sg.id
  source_security_group_id = aws_security_group.demo_backend_task_sg.id
}

# VPC Endpoint for SSM API
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [data.aws_security_group.shared_vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-ssm-endpoint"
  }
}