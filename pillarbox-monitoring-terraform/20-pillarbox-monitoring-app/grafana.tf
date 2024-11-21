# -----------------------------------
# AWS Grafana Workspace Setup
# -----------------------------------

# Security Group for Grafana
resource "aws_security_group" "grafana_sg" {
  name   = "grafana-sg"
  vpc_id = data.aws_vpc.main_vpc.id

  # Ingress rule: Allow inbound traffic from OpenSearch on port 443
  ingress {
    description = "Allow all inbound traffic from OpenSearch"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust CIDR block to restrict access
  }

  # Egress rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grafana-sg"
  }
}

## Create a Grafana Workspace for monitoring with OpenSearch as the data source

resource "aws_grafana_workspace" "grafana_workspace" {
  name                      = "${var.application_name}-grafana"
  account_access_type       = "CURRENT_ACCOUNT"                       # Restrict Grafana workspace to the current AWS account
  authentication_providers  = ["AWS_SSO"]                             # Use AWS SSO for authentication
  permission_type           = "SERVICE_MANAGED"                       # Permissions managed by the service
  role_arn                  = aws_iam_role.grafana_workspace_role.arn # IAM Role to assume for workspace access
  data_sources              = ["AMAZON_OPENSEARCH_SERVICE"]           # Data source for Grafana
  notification_destinations = ["SNS"]

  # VPC Configuration: Attach workspace to subnets and security group
  vpc_configuration {
    subnet_ids         = data.aws_subnets.public_subnets.ids
    security_group_ids = [aws_security_group.grafana_sg.id]
  }

  # Grafana Configuration
  configuration = jsonencode(
    {
      "plugins" = {
        "pluginAdminEnabled" = true
      },
      "unifiedAlerting" = {
        "enabled" = true
      }
    }
  )

  tags = {
    Name = "grafana-workspace"
  }
}

# -----------------------------------
# AWS SNS Topic for Alerts
# -----------------------------------

# Create an SNS Topic for Grafana Alerts
resource "aws_sns_topic" "grafana_alerts" {
  name = "grafana-alerts"

  tags = {
    Name = "grafana-alert-sns-topic"
  }
}

# Create SNS Topic Subscriptions for Email List
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.grafana_alerts.arn
  protocol  = "email"
  endpoint  = each.key
}
