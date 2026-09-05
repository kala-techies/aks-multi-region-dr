variable "name" {
  type        = string
  description = "AKS cluster name."
}

variable "location" {
  type        = string
  description = "Azure region for this cluster."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the cluster is created in."
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for the cluster API server."
}

variable "subnet_id" {
  type        = string
  description = "Subnet the node pool's VMs are attached to."
}

variable "node_vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = <<-EOT
    VM size for the system node pool. Defaults to Standard_B2s (2 vCPU) because
    Azure Free Trial subscriptions carry a documented 4 total vCPU quota cap
    with no increase eligibility - two single-node B2s clusters (one per
    region) already consume the entire quota. See DECISIONS.md AD-005.
  EOT
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Number of nodes in the system pool. Kept at 1 for the POC due to the vCPU quota constraint - see AD-005."
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Kubernetes version. Leave null to use the AKS default supported version."
}

variable "sku_tier" {
  type        = string
  default     = "Free"
  description = "AKS control plane tier. Free has no SLA and no cost; Standard/Premium add an hourly control-plane fee. See DECISIONS.md AD-005."
}

variable "tags" {
  type    = map(string)
  default = {}
}
