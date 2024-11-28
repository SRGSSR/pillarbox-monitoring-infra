# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "pillarbox-monitoring-tfstate"
    key            = "terraform/20-pillarbox-monitoring-app/terraform.tfstate"
    dynamodb_table = "pillarbox-monitoring-terraform-statelock"
    profile        = "prod"
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

# Retrieve private route tables based on VPC and tags
data "aws_route_tables" "private_route_tables" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  tags = {
    Name = "*private*"
  }
}

# -----------------------------------
# AWS ECS and Service Discovery Setup
# -----------------------------------

# Create Service Discovery namespace for the VPC
resource "aws_service_discovery_private_dns_namespace" "service_discovery_namespace" {
  name = var.private_domain_name
  vpc  = data.aws_vpc.main_vpc.id
}

# Create ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.ecs_cluster_name
}

# -----------------------------------
# AWS VPC Endpoints Setup
# -----------------------------------

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Associated to ECR/s3 VPC Endpoints"
  vpc_id      = local.vpc_id

  # Ingress rule to allow access to VPC endpoints
  ingress {
    description = "Allow Nodes to pull images from ECR via VPC endpoints"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    security_groups = [
      aws_security_group.dispatch_task_sg.id,
      aws_security_group.transfer_task_sg.id,
    ]
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}

# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-ecr-api-endpoint"
  }
}

# VPC Endpoint for ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-ecr-dkr-endpoint"
  }
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.main_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = data.aws_route_tables.private_route_tables.ids

  tags = {
    Name = "vpc-s3-endpoint"
  }
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-cloudwatch-logs-endpoint"
  }
}


# Security Group for the SNS VPC Endpoint
resource "aws_security_group" "sns_vpc_endpoint_sg" {
  name        = "sns-vpc-endpoint-sg"
  description = "Associated to SNS Endpoint"
  vpc_id      = local.vpc_id

  # Ingress rule to allow access to VPC endpoints
  ingress {
    description     = "Allow Grafana to publish to SNS topics"
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.grafana_sg.id]
  }

  tags = {
    Name = "sns-vpc-endpoint-sg"
  }
}

# VPC Endpoint for SNS
resource "aws_vpc_endpoint" "sns" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.sns_vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-sns-endpoint"
  }
}
