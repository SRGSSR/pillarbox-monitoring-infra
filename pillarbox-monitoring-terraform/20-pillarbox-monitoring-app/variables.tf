variable "application_name" {
  description = "The name of the application"
  type        = string
  default     = "pillarbox-monitoring"
}

variable "account_ids" {
  description = "Account id map by terraform workspace"
  type        = map(string)
}

variable "vpc_ids" {
  description = "VPC id map by terraform workspace"
  type        = map(string)
}

variable "private_domain_name" {
  description = "The domain name for the service discovery inside the vpc"
  type        = string
  default     = "monioring.pillarbox.local"
}

variable "pillarbox_domain_name" {
  description = "The public domain name of the service"
  type        = string
  default     = "pillarbox.ch"
}

variable "alert_emails" {
  description = "List of email addresses to subscribe to SNS topic for Grafana alerts"
  type        = list(string)
}
