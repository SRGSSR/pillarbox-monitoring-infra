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


# -----------------------------------
# Opensearch Host Policies
# -----------------------------------

resource "aws_iam_role" "opensearch_ec2_role" {
  name = "opensearch-ec2-role"

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

resource "aws_iam_policy" "opensearch_ssm_policy" {
  name        = "opensearch-ssm-policy"
  description = "Allows EC2 to read Opensearch admin password from SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ssm:GetParameter",
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:parameter/opensearch/admin_password"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "opensearch_ssm_policy_attach" {
  role       = aws_iam_role.opensearch_ec2_role.name
  policy_arn = aws_iam_policy.opensearch_ssm_policy.arn
}

resource "aws_iam_instance_profile" "opensearch_instance_profile" {
  name = "opensearch-instance-profile"
  role = aws_iam_role.opensearch_ec2_role.name
}
