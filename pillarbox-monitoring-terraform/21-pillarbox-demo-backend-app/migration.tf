# -----------------------------------
# One-time migration to 12-pillarbox-monitoring-shared
# -----------------------------------
#
# The SSM VPC endpoint is now owned by 12-pillarbox-monitoring-shared. This drops
# it from this state without destroying it.
#
# Delete this file once `terraform apply` has run in both the dev and prod workspaces.

removed {
  from = aws_vpc_endpoint.ssm
  lifecycle {
    destroy = false
  }
}
