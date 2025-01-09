# -----------------------------------
# Terraform Configuration
# -----------------------------------

terraform {
  # Backend configuration for storing the Terraform state in S3 with DynamoDB table for state locking
  backend "s3" {
    encrypt        = true
    bucket         = "rts-digital-terraform-backends-53a0d15f"
    key            = "pillarbox-monitoring-infra/10-pillarbox-monitoring-route-53.tfstate"
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
# AWS Route 53 Configuration
# -----------------------------------

## Create Route 53 Hosted Zone

resource "aws_route53_zone" "main_zone" {
  # Define the domain name for the hosted zone
  name = var.domain_name

  # Assign tags to the hosted zone
  tags = {
    Name = "${var.domain_name}-main-zone"
  }
}

# -----------------------------------
# IAM Configuration for Route 53 Access
# -----------------------------------

## Define IAM Policy Document for Route 53 Access

data "aws_iam_policy_document" "route53_access_policy" {
  # Create a policy that allows necessary Route 53 actions
  statement {
    sid    = "AllowRoute53Management"
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:GetHostedZone",
      "route53:GetChange",
      "route53:ListTagsForResource",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
    ]

    # Specify the resource ARNs; use "*" for all resources or specify exact ARNs
    resources = ["*"]
  }
}

## Define IAM Policy Document for Assume Role

data "aws_iam_policy_document" "route53_assume_role_policy" {
  # Allow specified principals to assume this role
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_account_ids
    }

    actions = ["sts:AssumeRole"]
  }
}

## Create IAM Role for Route 53 Access

resource "aws_iam_role" "route53_access_role" {
  # Create an IAM role to be assumed by entities that need Route 53 access
  name               = "route53-access-role"
  assume_role_policy = data.aws_iam_policy_document.route53_assume_role_policy.json

  # Attach the inline policy for Route 53 access
  inline_policy {
    name   = "Route53AccessPolicy"
    policy = data.aws_iam_policy_document.route53_access_policy.json
  }

  # Assign tags to the IAM role
  tags = {
    Name = "Route53AccessRole"
  }
}

# -----------------------------------
# Route 53 Github Configuration
# -----------------------------------

# Define a new Route 53 CNAME Record for GitHub Pages
resource "aws_route53_record" "github_pages_cname" {
  for_each = var.github_sub_domains
  zone_id  = aws_route53_zone.main_zone.zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "CNAME"
  ttl      = 300
  records  = ["srgssr.github.io"]
}
