variable "name" {
  type        = string
  description = "Container group name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "dns_name_label" {
  type        = string
  description = "Public DNS label. Final FQDN is <dns_name_label>.<location>.azurecontainer.io - must be globally unique within the region."
}

variable "acr_login_server" {
  type = string
}

variable "acr_admin_username" {
  type = string
}

variable "acr_admin_password" {
  type      = string
  sensitive = true
}

variable "frontend_image" {
  type        = string
  description = "Full image reference, e.g. <acr_login_server>/resilientops-frontend:<tag>."
}

variable "backend_image" {
  type        = string
  description = "Full image reference, e.g. <acr_login_server>/resilientops-backend:<tag>."
}

variable "backend_environment_variables" {
  type    = map(string)
  default = {}
}

variable "backend_secure_environment_variables" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "frontend_cpu" {
  type    = number
  default = 0.25
}

variable "frontend_memory_gb" {
  type    = number
  default = 0.5
}

variable "backend_cpu" {
  type    = number
  default = 0.5
}

variable "backend_memory_gb" {
  type    = number
  default = 1.0
}

variable "tags" {
  type    = map(string)
  default = {}
}
