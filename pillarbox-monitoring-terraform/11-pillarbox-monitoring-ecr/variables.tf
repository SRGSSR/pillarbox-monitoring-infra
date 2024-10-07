# See https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
variable "github_thumbprint_list" {
  type        = list(string)
  description = "Github Thumbprint list"
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

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
