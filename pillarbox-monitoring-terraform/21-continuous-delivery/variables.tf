variable "application_name" {
  description = "The name of the application"
  type        = string
  default     = "pillarbox-monitoring"
}

# See https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
variable "github_thumbprint_list" {
  type        = list(string)
  description = "Github Thumbprint list"
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

variable "service_mappings" {
  description = "Service mapping to Github repository and ECR image name"
  type = map(object({
    github_repo_name = string
    ecr_image_name   = string
    ecs              = bool
  }))

  default = {
    "dispatch-service" = {
      github_repo_name = "SRGSSR/pillarbox-event-dispatcher"
      ecr_image_name   = "pillarbox-event-dispatcher"
      ecs              = true
    }
    "data-transfer-service" = {
      github_repo_name = "SRGSSR/pillarbox-monitoring-transfer"
      ecr_image_name   = "pillarbox-monitoring-transfer"
      ecs              = true
    }
    "pillarbox-demo-backend" = {
      github_repo_name = "SRGSSR/pillarbox-demo-backend"
      ecr_image_name   = "pillarbox-demo-backend"
      ecs              = false
    }
  }
}
