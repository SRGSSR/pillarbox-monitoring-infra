# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "rts-digital-terraform-backends-53a0d15f"
    key            = "pillarbox-monitoring-infra/12-pillarbox-monitoring-shared.tfstate"
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
