locals {
  ecs_cluster_name = "${var.application_name}-cluster"
  is_prod          = terraform.workspace == "prod"

  default_tags = {
    "srg-managed-by"    = "terraform"
    "srg-application"   = var.application_name
    "srg-owner"         = "pillarbox-team@rts.ch"
    "srg-businessowner" = "pillarbox"
    "srg-environment"   = terraform.workspace
  }
}
