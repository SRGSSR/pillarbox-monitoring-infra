locals {
  default_tags = {
    "srg-managed-by"    = "terraform"
    "srg-application"   = "pillarbox-monitoring"
    "srg-owner"         = "pillarbox-team@rts.ch"
    "srg-businessowner" = "pillarbox"
    "srg-environment"   = "prod"
    "srg-repository"    = "SRGSSR/pillarbox-monitoring-infra"
  }
}