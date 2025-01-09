locals {
  bastion_ami           = "ami-0d7c381edfc5ee30e"
  bastion_instance_type = "t4g.nano"
  vpc_id                = var.vpc_ids[terraform.workspace]

  default_tags = {
    "srg-managed-by"    = "terraform"
    "srg-application"   = var.application_name
    "srg-owner"         = "pillarbox-team@rts.ch"
    "srg-businessowner" = "pillarbox"
    "srg-environment"   = terraform.workspace
    "srg-repository"    = "SRGSSR/pillarbox-monitoring-infra"
  }
}
