# POC IMPLEMENTATION: a single VNet with one subnet for AKS nodes, no
# private endpoints / no delegated subnet for PostgreSQL (see modules/postgresql
# for the corresponding compromise on the database side).
#
# PRODUCTION RECOMMENDATION: add a delegated subnet + private DNS zone so
# PostgreSQL Flexible Server can use VNet-integrated private access instead
# of public network access with firewall rules.

resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.name_prefix}-aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_prefix]
}
