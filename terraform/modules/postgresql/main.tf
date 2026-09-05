# POC IMPLEMENTATION: public network access + firewall allow-list, instead of
# VNet-integrated private access. Keeps this module (and the two-region
# networking it would otherwise require: delegated subnets + private DNS
# zone + VNet peering) simple for a POC.
#
# PRODUCTION RECOMMENDATION: private access (VNet injection) with no public
# endpoint at all - see modules/network for the corresponding compromise.

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku_name   = var.sku_name
  storage_mb = var.storage_mb
  version    = var.create_mode == "Replica" ? null : var.postgres_version
  zone       = var.zone

  # administrator_login/password are only valid (and only meaningful) on the
  # primary server; a replica inherits them from its source.
  administrator_login    = var.create_mode == "Replica" ? null : var.administrator_login
  administrator_password = var.create_mode == "Replica" ? null : var.administrator_password

  create_mode      = var.create_mode
  source_server_id = var.source_server_id

  public_network_access_enabled = true

  tags = var.tags

  lifecycle {
    ignore_changes = [zone]
  }
}

# POC IMPLEMENTATION: allow Azure services (including AKS pods using their
# public egress IP) to reach the server. Documented here as a broad rule,
# not a silent default - production should scope this to the AKS clusters'
# actual egress IPs (e.g. via a NAT gateway with a static public IP) or,
# better, use private access entirely and drop this resource.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count            = var.create_mode == "Replica" ? 0 : 1
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
