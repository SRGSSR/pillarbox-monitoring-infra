variable "application_name" {
  description = "The name of the application"
  type        = string
  default     = "pillarbox-demo-backend"
}

variable "account_ids" {
  description = "Account id map by terraform workspace"
  type        = map(string)
}

variable "vpc_ids" {
  description = "VPC id map by terraform workspace"
  type        = map(string)
}

variable "pillarbox_domain_name" {
  description = "The public domain name of the service"
  type        = string
  default     = "pillarbox.ch"
}

variable "postgresql_admin_username" {
  description = "Postgresql default admin password by terraform workspace"
  type        = string
  sensitive   = true
}

variable "postgresql_default_password" {
  description = "Postgresql default admin password by terraform workspace"
  type        = map(string)
  sensitive   = true
}

variable "session_cookie_secret" {
  description = "The secret key used to sign the session cookie."
  type        = map(string)
  sensitive   = true
}

variable "auth_issuer" {
  description = "The Base URL of the Identity Provider by terraform workspace"
  type        = map(string)
}

variable "auth_client_id" {
  description = "The Client ID registered in the Auth Provider by terraform workspace"
  type        = map(string)
}

variable "auth_client_secret" {
  description = "The Client Secret for the application by terraform workspace"
  type        = map(string)
  sensitive   = true
}

variable "database_encryption_key" {
  description = "The Database Encryption Key for the application by terraform workspace"
  type        = map(string)
  sensitive   = true
}

variable "auth_scopes" {
  description = "Comma separated oidc scopes"
  type        = map(string)
}
