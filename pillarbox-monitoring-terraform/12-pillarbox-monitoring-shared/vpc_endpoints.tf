# -----------------------------------
# AWS VPC Endpoints Setup
# -----------------------------------

# Security Group for VPC Endpoints
#
# No inline ingress rules on purpose: each application stack authorizes its own
# security groups through standalone aws_security_group_rule resources. Inline
# rules here would be authoritative and wipe out the rules added by other stacks.
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Associated to ECR/s3 VPC Endpoints"
  vpc_id      = data.aws_vpc.main_vpc.id

  tags = {
    Name = "vpc-endpoints-sg"
  }
}

# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-ecr-api-endpoint"
  }
}

# VPC Endpoint for ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-ecr-dkr-endpoint"
  }
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-cloudwatch-logs-endpoint"
  }
}

# VPC Endpoint for SSM API
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private_subnets.ids
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "vpc-ssm-endpoint"
  }
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.main_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = data.aws_route_tables.private_route_tables.ids

  tags = {
    Name = "vpc-s3-endpoint"
  }
}
