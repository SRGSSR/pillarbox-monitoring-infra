# -----------------------------------
# One-time migration from 20-pillarbox-monitoring-app and 21-pillarbox-demo-backend-app
# -----------------------------------
#
# The bastion and the VPC endpoints used to be owned by the application stacks.
# These import blocks adopt the existing resources instead of recreating them.
#
# Delete this file once `terraform apply` has run in both the dev and prod
# workspaces: the lookups below fail on an environment where the resources do
# not exist yet.

data "aws_instance" "migration_bastion" {
  filter {
    name   = "tag:Name"
    values = ["bastion-host"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main_vpc.id]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "stopped"]
  }
}

data "aws_security_group" "migration_bastion_sg" {
  name   = "bastion-sg"
  vpc_id = data.aws_vpc.main_vpc.id
}

data "aws_security_group" "migration_vpc_endpoints_sg" {
  name   = "vpc-endpoints-sg"
  vpc_id = data.aws_vpc.main_vpc.id
}

data "aws_vpc_endpoint" "migration_endpoints" {
  for_each = toset(["ecr.api", "ecr.dkr", "logs", "ssm", "s3"])

  vpc_id       = data.aws_vpc.main_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
}

import {
  to = aws_key_pair.bastion_key
  id = "bastion-keypair"
}

import {
  to = aws_security_group.bastion_sg
  id = data.aws_security_group.migration_bastion_sg.id
}

import {
  to = aws_instance.bastion
  id = data.aws_instance.migration_bastion.id
}

import {
  to = aws_security_group.vpc_endpoints_sg
  id = data.aws_security_group.migration_vpc_endpoints_sg.id
}

import {
  to = aws_vpc_endpoint.ecr_api
  id = data.aws_vpc_endpoint.migration_endpoints["ecr.api"].id
}

import {
  to = aws_vpc_endpoint.ecr_dkr
  id = data.aws_vpc_endpoint.migration_endpoints["ecr.dkr"].id
}

import {
  to = aws_vpc_endpoint.cloudwatch_logs
  id = data.aws_vpc_endpoint.migration_endpoints["logs"].id
}

import {
  to = aws_vpc_endpoint.ssm
  id = data.aws_vpc_endpoint.migration_endpoints["ssm"].id
}

import {
  to = aws_vpc_endpoint.s3
  id = data.aws_vpc_endpoint.migration_endpoints["s3"].id
}
