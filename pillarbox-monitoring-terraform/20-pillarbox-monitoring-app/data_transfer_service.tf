# -----------------------------------
# Security Group for Data Transfer Task
# -----------------------------------

resource "aws_security_group" "transfer_task_sg" {
  name   = "data-transfer-task-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Egress rule allowing all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "data-transfer-task-sg"
  }
}

# -----------------------------------
# CloudWatch Log Group for Data Transfer Task
# -----------------------------------

resource "aws_cloudwatch_log_group" "transfer_log_group" {
  name              = "/ecs/pillarbox-monitoring-transfer"
  retention_in_days = 7 # Adjust the retention period as necessary

  tags = {
    Name = "data-transfer-log-group"
  }
}

# -----------------------------------
# ECS Task Definition for Data Transfer Service
# -----------------------------------

resource "aws_ecs_task_definition" "transfer_task" {
  family                   = "pillarbox-monitoring-transfer"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.transfer_task.cpu
  memory                   = local.transfer_task.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # Define the container and its configuration
  container_definitions = jsonencode([
    {
      name                   = "pillarbox-monitoring-transfer"
      image                  = "${local.ecr_repository}/pillarbox-monitoring-transfer:${local.ecr_image_tag}"
      readonlyRootFilesystem = true

      # Port mapping for the container
      portMappings = [
        {
          hostPort      = 8081
          containerPort = 8081
          protocol      = "tcp"
        }
      ]

      # Environment variables for connecting to SSE and OpenSearch services
      environment = [
        {
          name  = "PILLARBOX_MONITORING_DISPATCH_URI"
          value = "http://${aws_service_discovery_service.dispatch_service_discovery.name}.${aws_service_discovery_private_dns_namespace.service_discovery_namespace.name}:8080/events"
        },
        {
          name  = "PILLARBOX_MONITORING_OPENSEARCH_URI"
          value = "https://${aws_opensearch_domain.opensearch_domain.endpoint}:443"
        }
      ]

      # Log configuration to use AWS CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.transfer_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "data-transfer-task"
  }
}

# -----------------------------------
# ECS Service for Data Transfer Task
# -----------------------------------

## ECS Service for pillarbox-monitoring-transfer

resource "aws_ecs_service" "transfer_service" {
  name            = "data-transfer-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.transfer_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Network configuration, attaching the service to private subnets and security group
  network_configuration {
    subnets         = [data.aws_subnets.private_subnets.ids[0]]
    security_groups = [aws_security_group.transfer_task_sg.id]
  }

  tags = {
    Name = "data-transfer-service"
  }
}
