resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result
}

# ---------------------------------------------------------------------------
# Resource groups - one per region, plus one for the global (non-regional)
# Traffic Manager profile.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "primary" {
  name     = "rg-${var.name_prefix}-primary"
  location = var.primary_region
  tags     = var.tags
}

resource "azurerm_resource_group" "secondary" {
  name     = "rg-${var.name_prefix}-secondary"
  location = var.secondary_region
  tags     = var.tags
}

resource "azurerm_resource_group" "global" {
  name     = "rg-${var.name_prefix}-global"
  location = var.primary_region
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Networking - one VNet per region.
# ---------------------------------------------------------------------------

module "network_primary" {
  source              = "../../modules/network"
  name_prefix         = "${var.name_prefix}-pri"
  location            = var.primary_region
  resource_group_name = azurerm_resource_group.primary.name
  address_space       = ["10.10.0.0/16"]
  aks_subnet_prefix   = "10.10.1.0/24"
  tags                = var.tags
}

module "network_secondary" {
  source              = "../../modules/network"
  name_prefix         = "${var.name_prefix}-sec"
  location            = var.secondary_region
  resource_group_name = azurerm_resource_group.secondary.name
  address_space       = ["10.20.0.0/16"]
  aks_subnet_prefix   = "10.20.1.0/24"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# AKS - one cluster per region. See modules/aks and DECISIONS.md AD-005 for
# why these are sized to exactly fit the Free Trial vCPU cap.
# ---------------------------------------------------------------------------

module "aks_primary" {
  source              = "../../modules/aks"
  name                = "aks-${var.name_prefix}-pri"
  location            = var.primary_region
  resource_group_name = azurerm_resource_group.primary.name
  dns_prefix          = "${var.name_prefix}pri"
  subnet_id           = module.network_primary.aks_subnet_id
  tags                = var.tags
}

module "aks_secondary" {
  source              = "../../modules/aks"
  name                = "aks-${var.name_prefix}-sec"
  location            = var.secondary_region
  resource_group_name = azurerm_resource_group.secondary.name
  dns_prefix          = "${var.name_prefix}sec"
  subnet_id           = module.network_secondary.aks_subnet_id
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Container registry - single Basic-tier registry in the primary region.
# See DECISIONS.md AD-004.
# ---------------------------------------------------------------------------

module "acr" {
  source              = "../../modules/acr"
  name                = "acr${var.name_prefix}${local.suffix}"
  location            = var.primary_region
  resource_group_name = azurerm_resource_group.primary.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull_primary" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks_primary.kubelet_identity_object_id
}

resource "azurerm_role_assignment" "acr_pull_secondary" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks_secondary.kubelet_identity_object_id
}

# ---------------------------------------------------------------------------
# PostgreSQL Flexible Server - primary + cross-region read replica.
# See DECISIONS.md AD-003.
# ---------------------------------------------------------------------------

module "postgres_primary" {
  source                 = "../../modules/postgresql"
  name                   = "psql-${var.name_prefix}-pri-${local.suffix}"
  location               = var.primary_region
  resource_group_name    = azurerm_resource_group.primary.name
  administrator_login    = var.postgres_administrator_login
  administrator_password = var.postgres_administrator_password
  tags                   = var.tags
}

module "postgres_replica" {
  source              = "../../modules/postgresql"
  name                = "psql-${var.name_prefix}-sec-${local.suffix}"
  location            = var.secondary_region
  resource_group_name = azurerm_resource_group.secondary.name
  create_mode         = "Replica"
  source_server_id    = module.postgres_primary.id
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Public IPs for each region's ingress LoadBalancer Service. Created here
# (rather than left to the AKS cloud-provider) so Terraform can hand a known,
# stable address to both Helm (as the Service's static IP) and Traffic
# Manager, breaking what would otherwise be a chicken-and-egg dependency.
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "primary_ingress" {
  name                = "pip-${var.name_prefix}-pri-ingress"
  location            = var.primary_region
  resource_group_name = module.aks_primary.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "secondary_ingress" {
  name                = "pip-${var.name_prefix}-sec-ingress"
  location            = var.secondary_region
  resource_group_name = module.aks_secondary.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Traffic Manager - DNS-level active-passive failover. See DECISIONS.md AD-006.
# ---------------------------------------------------------------------------

module "traffic_manager" {
  source              = "../../modules/traffic-manager"
  profile_name        = "${var.name_prefix}-${local.suffix}"
  resource_group_name = azurerm_resource_group.global.name
  primary_target      = azurerm_public_ip.primary_ingress.ip_address
  secondary_target    = azurerm_public_ip.secondary_ingress.ip_address
  tags                = var.tags
}
