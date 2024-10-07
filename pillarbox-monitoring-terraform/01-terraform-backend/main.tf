# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "pillarbox-monitoring-tfstate"
    key            = "terraform/01-terraform-backend/terraform.tfstate"
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
  # Apply default tags to all AWS resources
  default_tags {
    tags = local.default_tags
  }
}

# -----------------------------------
# AWS S3 Resources
# -----------------------------------

## Management S3 Bucket for Terraform State

resource "aws_s3_bucket" "s3-terraform" {
  count = 1

  # Name of the bucket for storing Terraform state
  bucket = "pillarbox-monitoring-tfstate"

  # Prevent accidental deletion of the bucket
  lifecycle {
    prevent_destroy = true
  }
}

## S3 Bucket Ownership Controls

resource "aws_s3_bucket_ownership_controls" "s3-ownership" {
  # Apply ownership controls to the S3 bucket
  bucket = one(aws_s3_bucket.s3-terraform[*].id)

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

## S3 Bucket ACL Configuration

resource "aws_s3_bucket_acl" "s3-acl_mgmt" {
  # Ensure this resource is created after the ownership controls
  depends_on = [aws_s3_bucket_ownership_controls.s3-ownership]

  count  = 1
  bucket = one(aws_s3_bucket.s3-terraform[*].id)
  acl    = "private"
}

# -----------------------------------
# AWS DynamoDB Resources
# -----------------------------------

## DynamoDB Table for Terraform State Locking

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  count = 1

  # Name of the DynamoDB table for state locking
  name           = "pillarbox-monitoring-terraform-statelock"
  hash_key       = "LockID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "LockID"
    type = "S"
  }
}
