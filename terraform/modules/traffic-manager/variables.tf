variable "profile_name" {
  type        = string
  description = "Traffic Manager profile name. Forms part of the public FQDN: <profile_name>.trafficmanager.net."
}

variable "resource_group_name" {
  type = string
}

variable "monitor_path" {
  type    = string
  default = "/healthz"
}

variable "primary_target" {
  type        = string
  description = "Public IP address or FQDN of the primary (West Europe) ingress."
}

variable "secondary_target" {
  type        = string
  description = "Public IP address or FQDN of the secondary (North Europe) ingress."
}

variable "tags" {
  type    = map(string)
  default = {}
}
