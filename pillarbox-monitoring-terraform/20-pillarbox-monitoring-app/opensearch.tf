# -----------------------------------
# OpenSearch Domain Setup
# -----------------------------------

resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name    = local.opensearch.domain_name
  engine_version = "OpenSearch_2.17"

  # Cluster configuration including instance type and count
  cluster_config {
    instance_type          = local.opensearch.instance_type
    instance_count         = length(data.aws_subnets.private_subnets.ids)
    zone_awareness_enabled = true

    # Zone awareness setup for availability across subnets
    zone_awareness_config {
      availability_zone_count = length(data.aws_subnets.private_subnets.ids)
    }
  }

  # EBS volume configuration for persistent storage
  ebs_options {
    ebs_enabled = true
    volume_size = local.opensearch.volume_size
    volume_type = local.opensearch.volume_type
    throughput  = local.opensearch.throughput
  }

  # VPC configuration linking to private subnets and security group
  vpc_options {
    subnet_ids         = data.aws_subnets.private_subnets.ids
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  # Access policies for OpenSearch, configured via IAM policy
  access_policies = data.aws_iam_policy_document.opensearch_policy.json

  # Log publishing options for CloudWatch logging
  log_publishing_options {
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_slow_logs.arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "SEARCH_SLOW_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_logs.arn
    enabled                  = true
  }

  log_publishing_options {
    log_type                 = "ES_APPLICATION_LOGS"
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_application_logs.arn
    enabled                  = true
  }

  tags = {
    Name = "opensearch-domain"
  }

  timeouts {
    create = "90m"
  }
}

# -----------------------------------
# CloudWatch Log Groups
# -----------------------------------

# Log Group for Slow Logs
resource "aws_cloudwatch_log_group" "opensearch_slow_logs" {
  name              = "/aws/opensearch/${local.opensearch.domain_name}/slow-logs"
  retention_in_days = 7
}

# Log Group for Search Logs
resource "aws_cloudwatch_log_group" "opensearch_search_logs" {
  name              = "/aws/opensearch/${local.opensearch.domain_name}/search-logs"
  retention_in_days = 7
}

# Log Group for Application Logs
resource "aws_cloudwatch_log_group" "opensearch_application_logs" {
  name              = "/aws/opensearch/${local.opensearch.domain_name}/application-logs"
  retention_in_days = 7
}

# -----------------------------------
# Security Group for OpenSearch
# -----------------------------------

# Private Access Security Group for OpenSearch
resource "aws_security_group" "opensearch_sg" {
  name   = "opensearch-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Ingress rule to allow access from specific services
  ingress {
    description = "Allow access from data-transfer and Grafana services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      aws_security_group.transfer_task_sg.id,
      aws_security_group.grafana_sg.id
    ]
  }

  # Egress rule to allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "opensearch-sg"
  }
}
