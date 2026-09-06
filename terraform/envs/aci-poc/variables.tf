variable "name_prefix" {
  type        = string
  default     = "resopsaci"
  description = "Short, lowercase-alphanumeric prefix for resource names (ACR/Postgres/DNS-label length and charset limits apply)."
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Single region - this environment is a smoke test, not the DR architecture (that's terraform/envs/dr-poc)."
}

variable "postgres_administrator_login" {
  type    = string
  default = "resopsadmin"
}

variable "postgres_administrator_password" {
  type        = string
  sensitive   = true
  description = "Supply via TF_VAR_postgres_administrator_password or an untracked terraform.tfvars - never commit it."
}

variable "backend_api_key" {
  type        = string
  sensitive   = true
  description = "Value of the backend's API_KEY - required for write endpoints. Supply via TF_VAR_backend_api_key. Never the app's committed dev default."
}

variable "frontend_image_tag" {
  type    = string
  default = "latest"
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "tags" {
  type = map(string)
  default = {
    project     = "aks-multi-region-dr"
    environment = "aci-poc"
  }
}
