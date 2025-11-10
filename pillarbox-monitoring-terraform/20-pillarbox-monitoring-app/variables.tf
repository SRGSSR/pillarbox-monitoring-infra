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

variable "grafana_default_pwd" {
  description = "Grafana default admin password"
  type        = string
}

variable "opensearch_default_pwd" {
  description = "Opensearch default admin password"
  type        = string
}

variable "bastion_public_key" {
  description = "Public key for the bastion host"
  type        = string
}

variable "bastion_allowed_ips" {
  description = "The list of ips that are allowed to connect to the bastion"
  type        = list(string)
}
