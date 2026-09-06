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

variable "admin_enabled" {
  type        = bool
  default     = false
  description = "Enables the ACR admin account (shared username/password). Kept false by default (AKS pulls via managed identity + AcrPull instead); the aci-poc environment turns this on because Azure Container Instances needs registry credentials, not a managed identity, to pull images - see DECISIONS.md AD-010."
}

variable "tags" {
  type    = map(string)
  default = {}
}
