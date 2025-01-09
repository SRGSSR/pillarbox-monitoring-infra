# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "rts-digital-terraform-backends-53a0d15f"
    key            = "pillarbox-monitoring-infra/11-pillarbox-monitoring-ecr.tfstate"
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
# Amazon ECR Repositories
# -----------------------------------

## Create ECR Repositories

resource "aws_ecr_repository" "repositories" {
  # Iterate over the list of ECR repositories to create
  for_each = var.ecr_repositories
  name     = each.key

  # Assign tags to each repository
  tags = {
    Name = "${each.key}-ecr"
  }
}

## Configure ECR Lifecycle Policies

resource "aws_ecr_lifecycle_policy" "ecr_lifecycles" {
  # Apply lifecycle policies to each ECR repository
  for_each   = var.ecr_repositories
  repository = aws_ecr_repository.repositories[each.key].name

  # Policy to retain only the last 10 images
  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

# -----------------------------------
# Cross-Account ECR Access Configuration
# -----------------------------------

## Define IAM Policy Document for Cross-Account Access

data "aws_iam_policy_document" "inter_account_policy" {
  # Create a policy to allow the development account to pull images from ECR
  statement {
    sid    = "AllowPullFromDevelopmentAccount"
    effect = "Allow"

    # Specify the AWS account ID that is allowed access
    principals {
      type        = "AWS"
      identifiers = var.allowed_account_ids
    }

    # Actions permitted for the development account
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
  }
}

## Attach Repository Policy for Inter-Account Access

resource "aws_ecr_repository_policy" "inter_account_ecr_policy" {
  # Apply the inter-account policy to each ECR repository
  for_each   = var.ecr_repositories
  repository = each.key
  policy     = data.aws_iam_policy_document.inter_account_policy.json
}
