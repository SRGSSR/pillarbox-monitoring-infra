locals {
  account_id       = var.account_ids[terraform.workspace]
  vpc_id           = var.vpc_ids[terraform.workspace]
  ecs_cluster_name = "${var.application_name}-cluster"
  is_prod          = terraform.workspace == "prod"
  ecr_repository   = "${var.account_ids["prod"]}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  ecr_image_tag    = local.is_prod ? "stable" : "latest"

  opensearch = {
    domain_name   = "${var.application_name}-search"
    volume_size   = local.is_prod ? 300 : 10
    instance_type = local.is_prod ? "m7g.medium.search" : "t3.small.search"
    volume_type   = local.is_prod ? "gp3" : "gp2"
    throughput    = local.is_prod ? 250 : null
  }

  il_proxy = {
    ami           = "ami-0d7c381edfc5ee30e"
    instance_type = "t4g.nano"
    api_key       = var.il_proxy_api_key[terraform.workspace]
  }

  domain_name = local.is_prod ? "monitoring.pillarbox.ch" : "dev.monitoring.pillarbox.ch"

  transfer_task = {
    cpu       = local.is_prod ? 2048 : 512
    memory    = local.is_prod ? 16384 : 1024
    java_opts = local.is_prod ? "-Xms14G -Xmx14G" : "-Xms1G -Xmx1G"
  }

  dispatch_task = {
    cpu    = local.is_prod ? 1024 : 256
    memory = local.is_prod ? 2048 : 512
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
