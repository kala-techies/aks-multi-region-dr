# POC IMPLEMENTATION: Traffic Manager Priority routing (DNS-level, cheap).
# See DECISIONS.md AD-006 - failover is bounded by DNS TTL, not instant.
#
# PRODUCTION RECOMMENDATION: Azure Front Door Premium for HTTP-layer
# failover (seconds, not TTL-bound) plus WAF and edge TLS termination.

resource "azurerm_traffic_manager_profile" "this" {
  name                   = var.profile_name
  resource_group_name    = var.resource_group_name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = var.profile_name
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = var.monitor_path
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = var.tags
}

resource "azurerm_traffic_manager_external_endpoint" "primary" {
  name       = "primary-westeurope"
  profile_id = azurerm_traffic_manager_profile.this.id
  target     = var.primary_target
  priority   = 1
}

resource "azurerm_traffic_manager_external_endpoint" "secondary" {
  name       = "secondary-northeurope"
  profile_id = azurerm_traffic_manager_profile.this.id
  target     = var.secondary_target
  priority   = 2
}
