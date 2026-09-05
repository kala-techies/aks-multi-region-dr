# POC IMPLEMENTATION: single Basic-tier registry in the primary region only.
# The secondary region's AKS cluster pulls images cross-region from here.
# See DECISIONS.md AD-004 - geo-replication requires Premium (~$50/month per
# replicated region), rejected on cost grounds for the Free Trial POC.
#
# PRODUCTION RECOMMENDATION: Premium tier with geo-replication to the
# secondary region, so each cluster pulls from an in-region replica.

resource "azurerm_container_registry" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
