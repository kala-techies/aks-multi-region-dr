variable "name" {
  type        = string
  description = "ACR name. Must be globally unique, alphanumeric only."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "Basic tier has no geo-replication support - see DECISIONS.md AD-004. Use Premium for geo-replication."
}

variable "tags" {
  type    = map(string)
  default = {}
}
