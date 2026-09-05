variable "name_prefix" {
  type        = string
  default     = "notesdr"
  description = "Short, globally-unique-safe prefix used to build resource names (keep lowercase alphanumeric, <= 8 chars, since ACR/PostgreSQL names have tight length/charset limits)."
}

variable "primary_region" {
  type    = string
  default = "westeurope"
}

variable "secondary_region" {
  type    = string
  default = "northeurope"
}

variable "postgres_administrator_login" {
  type        = string
  default     = "notesadmin"
  description = "PostgreSQL superuser login."
}

variable "postgres_administrator_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL superuser password. Supply via TF_VAR_postgres_administrator_password env var or an untracked terraform.tfvars - never commit it. No default on purpose."
}

variable "tags" {
  type = map(string)
  default = {
    project     = "aks-multi-region-dr"
    environment = "poc"
  }
}
