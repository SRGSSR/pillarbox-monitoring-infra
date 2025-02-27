# -----------------------------------
# IAM Policy for ECS Task Assume Role
# -----------------------------------

# ECS Task Assume Role Policy Document
data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

# Attach ECS Task Execution Policy to Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Conditional Policy for Cross-Account Access to ECR (for non-prod environments)
resource "aws_iam_role_policy" "ecr_cross_account_access" {
  count = local.is_prod ? 0 : 1
  role  = aws_iam_role.ecs_task_execution_role.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Resource": "arn:aws:ecr:${data.aws_region.current.name}:${var.account_ids["prod"]}:repository/*"
    }
  ]
}
EOF
}

# Attach ECR Read-Only Policy for Production
resource "aws_iam_role_policy_attachment" "ecr_read_access" {
  count      = local.is_prod ? 1 : 0
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -----------------------------------
# IAM Role for ECS Tasks
# -----------------------------------

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs_task_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

# -----------------------------------
# OpenSearch Policies for ECS Tasks
# -----------------------------------

# OpenSearch Policy Document for ECS Tasks
data "aws_iam_policy_document" "ecs_task_opensearch_policy" {
  statement {
    actions   = ["es:ESHttp*"]
    resources = ["${aws_opensearch_domain.opensearch_domain.arn}/*"]
  }
}

# OpenSearch Policy for ECS Tasks
resource "aws_iam_policy" "ecs_task_opensearch_policy" {
  name   = "ecs_task_opensearch_policy"
  policy = data.aws_iam_policy_document.ecs_task_opensearch_policy.json
}

# Attach OpenSearch Policy to ECS Task Role
resource "aws_iam_role_policy_attachment" "ecs_task_opensearch_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_opensearch_policy.arn
}

# -----------------------------------
# OpenSearch Access Policies
# -----------------------------------

# OpenSearch Domain Access Policy
data "aws_iam_policy_document" "opensearch_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["es:*"]
    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${local.account_id}:domain/${local.opensearch.domain_name}/*"
    ]
  }
}

# -----------------------------------
# CloudWatch Log Policy for OpenSearch
# -----------------------------------

# Policy Document for OpenSearch Logging in CloudWatch
data "aws_iam_policy_document" "opensearch_log_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }

    actions = [
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
      "logs:CreateLogStream",
    ]

    resources = ["arn:aws:logs:*"]
  }
}

# Attach CloudWatch Log Policy for OpenSearch
resource "aws_cloudwatch_log_resource_policy" "opensearch_log_policy" {
  policy_name     = "opensearch-logging-policy"
  policy_document = data.aws_iam_policy_document.opensearch_log_policy.json
}

# -----------------------------------
# Grafana Host Policies
# -----------------------------------

resource "aws_iam_role" "grafana_ec2_role" {
  name = "grafana-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "grafana_ssm_policy" {
  name        = "grafana-ssm-policy"
  description = "Allows EC2 to read Grafana admin password from SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ssm:GetParameter",
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:parameter/grafana/admin_password"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_ssm_policy_attach" {
  role       = aws_iam_role.grafana_ec2_role.name
  policy_arn = aws_iam_policy.grafana_ssm_policy.arn
}

resource "aws_iam_instance_profile" "grafana_instance_profile" {
  name = "grafana-instance-profile"
  role = aws_iam_role.grafana_ec2_role.name
}
