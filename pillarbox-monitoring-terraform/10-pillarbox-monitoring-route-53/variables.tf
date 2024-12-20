variable "domain_name" {
  description = "The domain name of the monitoring system"
  type        = string
  default     = "pillarbox.ch"
}

variable "allowed_account_ids" {
  description = "The ids allows to access the route 53 main zone resource"
  type        = list(string)
}

variable "github_sub_domains" {
  type    = set(string)
  default = ["demo", "www", "web", "android", "editor", "plugins"]
}
