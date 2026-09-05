variable "name" {
  type        = string
  description = "Flexible Server name. Must be globally unique."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku_name" {
  type        = string
  default     = "B_Standard_B1ms"
  description = "Burstable B1ms - cheapest tier suitable for a low-traffic POC. NOT suitable for production load. See DECISIONS.md AD-003."
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "administrator_login" {
  type        = string
  description = "Superuser login name. Ignored when create_mode = \"Replica\"."
  default     = null
}

variable "administrator_password" {
  type        = string
  description = "Superuser password. Must be supplied via TF_VAR_administrator_password or an untracked .tfvars file - never committed. Ignored when create_mode = \"Replica\"."
  default     = null
  sensitive   = true
}

variable "create_mode" {
  type        = string
  default     = null
  description = "Set to \"Replica\" to create this server as a cross-region read replica of source_server_id."
}

variable "source_server_id" {
  type        = string
  default     = null
  description = "Required when create_mode = \"Replica\": the resource ID of the primary Flexible Server."
}

variable "zone" {
  type        = string
  default     = null
  description = "Availability zone. Leave null to let Azure choose (required for some replica configurations)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
