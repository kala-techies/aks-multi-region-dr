# POC IMPLEMENTATION: Free-tier control plane, single-node Burstable pool,
# kubenet networking (avoids needing a large pre-allocated subnet the way
# Azure CNI does). Sized entirely around the Azure Free Trial 4 vCPU cap -
# see DECISIONS.md AD-005 for the full reasoning and the risk this carries.
#
# PRODUCTION RECOMMENDATION: Standard/Premium SKU tier for an SLA, Azure CNI
# (or CNI Overlay) networking, a system pool separated from user workload
# pools, and at least 3 nodes across availability zones for real HA.

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  default_node_pool {
    name            = "system"
    vm_size         = var.node_vm_size
    node_count      = var.node_count
    vnet_subnet_id  = var.subnet_id
    os_disk_size_gb = 30
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
  }

  tags = var.tags
}
