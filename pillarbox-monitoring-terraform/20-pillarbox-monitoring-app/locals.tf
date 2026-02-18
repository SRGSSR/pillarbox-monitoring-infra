locals {
  account_id = var.account_ids[terraform.workspace]
  vpc_id     = var.vpc_ids[terraform.workspace]
  is_prod    = terraform.workspace == "prod"

  ecs_cluster_name = "${var.application_name}-cluster"
  ecr_repository   = "${var.account_ids["prod"]}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  ecr_image_tag    = local.is_prod ? "stable" : "latest"

  opensearch = {
    ami           = "ami-0d7c381edfc5ee30e"
    domain_name   = "${var.application_name}-search"
    instance_type = local.is_prod ? "r7g.xlarge" : "t4g.medium"
    volume = {
      type       = "gp3"
      size       = local.is_prod ? 750 : 20,
      iops       = 3000
      throughput = 125
    }
    java_opts = local.is_prod ? "-Xms16g -Xmx16g" : "-Xms2g -Xmx2g"
  }

  grafana = {
    ami           = "ami-0d7c381edfc5ee30e"
    instance_type = "t4g.medium"
    domain_name   = local.is_prod ? "grafana.${var.pillarbox_domain_name}" : "dev.grafana.${var.pillarbox_domain_name}"
  }

  transfer = {
    task = {
      cpu         = local.is_prod ? 2048 : 256
      memory      = local.is_prod ? 16384 : 1024
      sse_timeout = local.is_prod ? "12000" : "86400000"
    }
  }

  dispatch = {
    domain_name = local.is_prod ? "monitoring.${var.pillarbox_domain_name}" : "dev.monitoring.${var.pillarbox_domain_name}"
    task = {
      cpu    = local.is_prod ? 1024 : 256
      memory = local.is_prod ? 2048 : 512
    }
  }

  bastion = {
    ami           = "ami-0d7c381edfc5ee30e"
    instance_type = "t4g.nano"
  }

  default_tags = {
    "srg-managed-by"    = "terraform"
    "srg-application"   = var.application_name
    "srg-owner"         = "pillarbox-team@rts.ch"
    "srg-businessowner" = "pillarbox"
    "srg-environment"   = terraform.workspace
    "srg-repository"    = "SRGSSR/pillarbox-monitoring-infra"
  }
}
