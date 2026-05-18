locals {
  account_id = var.account_ids[terraform.workspace]
  vpc_id     = var.vpc_ids[terraform.workspace]
  is_prod    = terraform.workspace == "prod"

  auth_issuer             = var.auth_issuer[terraform.workspace]
  auth_client_id          = var.auth_client_id[terraform.workspace]
  auth_client_secret      = var.auth_client_secret[terraform.workspace]
  auth_scopes             = var.auth_scopes[terraform.workspace]
  session_cookie_secret   = var.session_cookie_secret[terraform.workspace]
  database_encryption_key = var.database_encryption_key[terraform.workspace]

  ecs_cluster_name = "${var.application_name}-cluster"
  ecr_repository   = "${var.account_ids["prod"]}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  ecr_image_tag    = local.is_prod ? "stable" : "latest"

  postgresql = {
    engine_version    = "18.3"
    instance_class    = "db.t4g.micro"
    allocated_storage = local.is_prod ? 20 : 5
    db_name           = "pillarbox"
    username          = var.postgresql_admin_username
    password          = var.postgresql_default_password[terraform.workspace]
  }

  demo-backend = {
    domain_name = local.is_prod ? "api.${var.pillarbox_domain_name}" : "dev.api.${var.pillarbox_domain_name}"
    task = {
      cpu    = 512
      memory = 1024
    }
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
