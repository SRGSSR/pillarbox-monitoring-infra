variable "application_name" {
  description = "The name of the application"
  type        = string
  default     = "pillarbox-monitoring"
}

variable "vpc_ids" {
  description = "VPC id map by terraform workspace"
  type        = map(string)
}

# Variable for Public Key
variable "bastion_public_key" {
  description = "Public key for the bastion host"
  type        = string
}

variable "allowed_ips" {
  description = "The list of ips that are allowed to connect to the bastion"
  type        = list(string)
}
