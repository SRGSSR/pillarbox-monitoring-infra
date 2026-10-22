# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "rts-digital-terraform-backends-53a0d15f"
    key            = "pillarbox-monitoring-infra/20-pillarbox-monitoring-app.tfstate"
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

# Retrieve the shared Bastion security group (12-pillarbox-monitoring-shared)
data "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = data.aws_vpc.main_vpc.id
}

# Retrieve the shared VPC endpoints security group (12-pillarbox-monitoring-shared)
data "aws_security_group" "vpc_endpoints_sg" {
  name   = "vpc-endpoints-sg"
  vpc_id = data.aws_vpc.main_vpc.id
}

# -----------------------------------
# AWS Route 53 zone data lookup
# -----------------------------------

data "aws_route53_zone" "main_zone" {
  provider = aws.prod
  name     = var.pillarbox_domain_name
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
# Shared VPC Endpoints Access
# -----------------------------------

# Allow the tasks of this stack to reach ECR/Logs/SSM via the shared endpoints
resource "aws_security_group_rule" "allow_to_shared_endpoints" {
  for_each = merge(
    {
      dispatch = aws_security_group.dispatch_task_sg.id
      transfer = aws_security_group.transfer_task_sg.id
    },
    # Reads its admin password through the SSM endpoint (prod only)
    { for id in aws_security_group.quanthea_sg[*].id : "quanthea" => id },
  )

  type        = "ingress"
  description = "Allow Nodes to pull images from ECR via VPC endpoints"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"

  security_group_id        = data.aws_security_group.vpc_endpoints_sg.id
  source_security_group_id = each.value
}
