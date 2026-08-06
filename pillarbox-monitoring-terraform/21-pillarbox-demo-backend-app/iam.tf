# -----------------------------------
# IAM Roles and policies for ECS Tasks
# -----------------------------------


# ECS Task Assume Role Policy Document
data "aws_iam_policy_document" "demo_backend_ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "demo_backend_ecs_task_execution_role" {
  name               = "demo_backend_ecs_task_execution_role"
  assume_role_policy = data.aws_iam_policy_document.demo_backend_ecs_task_assume_role_policy.json
}

# Attach ECS Task Execution Policy to Execution Role
resource "aws_iam_role_policy_attachment" "demo_backend_ecs_task_execution_policy" {
  role       = aws_iam_role.demo_backend_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Conditional Policy for Cross-Account Access to ECR (for non-prod environments)
resource "aws_iam_role_policy" "ecr_cross_account_access" {
  count = local.is_prod ? 0 : 1
  role  = aws_iam_role.demo_backend_ecs_task_execution_role.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        "Resource" : "arn:aws:ecr:${data.aws_region.current.name}:${var.account_ids["prod"]}:repository/${var.application_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_access" {
  role = aws_iam_role.demo_backend_ecs_task_execution_role.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:parameter/demo-backend/*",
          "arn:aws:ssm:${data.aws_region.current.name}:${local.account_id}:parameter/postgresql/*"
        ]
      }
    ]
  })
}

# Attach ECR Read-Only Policy for Production
resource "aws_iam_role_policy_attachment" "ecr_read_access" {
  count      = local.is_prod ? 1 : 0
  role       = aws_iam_role.demo_backend_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ECS Task Role
resource "aws_iam_role" "demo_backend_ecs_task_role" {
  name               = "demo_backend_ecs_task_role"
  assume_role_policy = data.aws_iam_policy_document.demo_backend_ecs_task_assume_role_policy.json
}
