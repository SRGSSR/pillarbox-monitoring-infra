# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "pillarbox-monitoring-tfstate"
    key            = "terraform/11-pillarbox-monitoring-ecr/terraform.tfstate"
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
  for_each = var.ecr_repositories

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
      values   = ["repo:${each.value}:*"]
    }
  }
}

### Permissions Policy Document

data "aws_iam_policy_document" "gha_policy" {
  # Define permissions for GitHub Actions to interact with ECR
  for_each = var.ecr_repositories

  # Allow Docker login to ECR
  statement {
    sid       = "AllowDockerLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Allow pushing and pulling images to/from ECR
  statement {
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
    resources = [aws_ecr_repository.repositories[each.key].arn]
  }
}

## Create IAM Roles for GitHub Actions

resource "aws_iam_role" "gha_role" {
  # Create IAM roles for each ECR repository for GitHub Actions
  for_each = var.ecr_repositories

  name               = "gh-actions-role-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_policy[each.key].json

  # Attach inline policy for ECR permissions
  inline_policy {
    name   = "GithubActionECRBuilds"
    policy = data.aws_iam_policy_document.gha_policy[each.key].json
  }
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
