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

variable "bastion_public_key" {
  description = "Public key for the bastion host"
  type        = string
}

variable "bastion_allowed_ips" {
  description = "The list of ips that are allowed to connect to the bastion"
  type        = list(string)
}
