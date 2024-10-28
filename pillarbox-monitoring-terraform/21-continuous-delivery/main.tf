# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "pillarbox-monitoring-tfstate"
    key            = "terraform/21-continuous-delivery/terraform.tfstate"
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
# AWS Data Sources
# -----------------------------------

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS identity
data "aws_caller_identity" "current" {}

# -----------------------------------
# IAM Configuration for GitHub Actions
# -----------------------------------

## Set Up OIDC Provider

resource "aws_iam_openid_connect_provider" "github_actions" {
  # Create an IAM OIDC provider for GitHub Actions
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_thumbprint_list
}

## Define IAM Policy Documents

### Assume Role Policy Document

data "aws_iam_policy_document" "gha_assume_policy" {
  # Generate policy documents for assuming IAM roles via OIDC
  for_each = var.service_mappings

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${each.value.github_repo_name}:*"]
    }
  }
}

### Permissions Policy Document

data "aws_iam_policy_document" "gha_policy" {
  # Define permissions for GitHub Actions to interact with ECR and ECS
  for_each = var.service_mappings

  # Allow Docker login to ECR
  dynamic "statement" {
    for_each = local.is_prod ? [1] : []

    content {
      sid       = "AllowDockerLogin"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  # Allow pushing and pulling images to/from ECR
  dynamic "statement" {
    for_each = local.is_prod ? [1] : []

    content {
      sid    = "AllowPushPull"
      effect = "Allow"
      actions = [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage"
      ]
      resources = [
        "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${each.value.ecr_image_name}"
      ]

    }
  }

  # Allow updating ECS services
  statement {
    sid    = "AllowUpdateService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices"
    ]
    resources = [
      "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${local.ecs_cluster_name}",
      "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/${local.ecs_cluster_name}/${each.key}"
    ]
  }
}

## Create IAM Roles for GitHub Actions

resource "aws_iam_role" "gha_role" {
  # Create IAM roles for each service
  for_each = var.service_mappings

  name               = "gh-actions-role-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_policy[each.key].json

  # Attach inline policy for ECR and ECS permissions
  inline_policy {
    name   = "GithubActionPermissions"
    policy = data.aws_iam_policy_document.gha_policy[each.key].json
  }
}


