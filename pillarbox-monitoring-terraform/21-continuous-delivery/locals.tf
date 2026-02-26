locals {
  ecs_cluster_name = "${var.application_name}-cluster"
  is_prod          = terraform.workspace == "prod"

  services_with_policy = tomap(
    {
      for k, v in var.service_mappings :
      k => v if(local.is_prod || v.ecs)
    }
  )

  default_tags = {
    "srg-managed-by"    = "terraform"
    "srg-application"   = var.application_name
    "srg-owner"         = "pillarbox-team@rts.ch"
    "srg-businessowner" = "pillarbox"
    "srg-environment"   = terraform.workspace
    "srg-repository"    = "SRGSSR/pillarbox-monitoring-infra"
  }
}
