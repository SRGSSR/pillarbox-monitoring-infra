variable "ecr_repositories" {
  description = "Map of ECR repository names to their associated GitHub repository"
  type        = map(string)
  default = {
    "pillarbox-event-dispatcher"    = "SRGSSR/pillarbox-event-dispatcher"
    "pillarbox-monitoring-transfer" = "SRGSSR/pillarbox-monitoring-transfer"
  }
}

variable "allowed_account_ids" {
  description = "Account id map by environment"
  type        = list(string)
}
