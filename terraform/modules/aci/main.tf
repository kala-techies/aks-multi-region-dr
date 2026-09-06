# POC IMPLEMENTATION: this whole module exists to answer one question -
# "does the image actually run and serve traffic in Azure?" - as cheaply
# and simply as possible, before committing to the full AKS multi-region
# path in ../aks. Both containers share one public IP (ACI's default
# networking); there is no ingress, no TLS, and no autoscaling here.
#
# PRODUCTION RECOMMENDATION: none - this module is intentionally a
# throwaway smoke-test rig, not a production deployment target. The
# production path for this workload is terraform/modules/aks.

locals {
  fqdn = "${var.dns_name_label}.${var.location}.azurecontainer.io"
}

resource "azurerm_container_group" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = var.dns_name_label
  restart_policy      = "Always"

  image_registry_credential {
    server   = var.acr_login_server
    username = var.acr_admin_username
    password = var.acr_admin_password
  }

  container {
    name   = "backend"
    image  = var.backend_image
    cpu    = var.backend_cpu
    memory = var.backend_memory_gb

    ports {
      port     = 8000
      protocol = "TCP"
    }

    environment_variables        = var.backend_environment_variables
    secure_environment_variables = var.backend_secure_environment_variables
  }

  container {
    name   = "frontend"
    image  = var.frontend_image
    cpu    = var.frontend_cpu
    memory = var.frontend_memory_gb

    ports {
      port     = 8080
      protocol = "TCP"
    }

    environment_variables = {
      FRONTEND_API_BASE_URL = "http://${local.fqdn}:8000"
    }
  }

  tags = var.tags
}
