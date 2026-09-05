variable "name_prefix" {
  type        = string
  description = "Prefix used for all resource names in this module."
}

variable "location" {
  type        = string
  description = "Azure region for this network."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the network is created in."
}

variable "address_space" {
  type        = list(string)
  description = "VNet address space, e.g. [\"10.0.0.0/16\"]."
}

variable "aks_subnet_prefix" {
  type        = string
  description = "CIDR for the AKS node subnet, e.g. \"10.0.1.0/24\"."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources in this module."
}
