locals {
  account_id = var.account_ids[terraform.workspace]
  vpc_id     = var.vpc_ids[terraform.workspace]

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
