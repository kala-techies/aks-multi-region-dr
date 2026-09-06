resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = var.tags
}

module "acr" {
  source              = "../../modules/acr"
  name                = "acr${var.name_prefix}${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  admin_enabled       = true # ACI needs registry credentials, not a managed identity - see DECISIONS.md AD-010
  tags                = var.tags
}

module "postgres" {
  source                 = "../../modules/postgresql"
  name                   = "psql-${var.name_prefix}-${local.suffix}"
  location               = var.location
  resource_group_name    = azurerm_resource_group.this.name
  administrator_login    = var.postgres_administrator_login
  administrator_password = var.postgres_administrator_password
  tags                   = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "resilientops"
  server_id = module.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

module "app" {
  source              = "../../modules/aci"
  name                = "aci-${var.name_prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  dns_name_label      = "${var.name_prefix}-${local.suffix}"

  acr_login_server   = module.acr.login_server
  acr_admin_username = module.acr.admin_username
  acr_admin_password = module.acr.admin_password

  frontend_image = "${module.acr.login_server}/resilientops-frontend:${var.frontend_image_tag}"
  backend_image  = "${module.acr.login_server}/resilientops-backend:${var.backend_image_tag}"

  backend_environment_variables = {
    REGION          = "${var.location}-aci"
    ALLOWED_ORIGINS = "*"
  }

  backend_secure_environment_variables = {
    DATABASE_URL = "postgresql+psycopg://${var.postgres_administrator_login}:${var.postgres_administrator_password}@${module.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
    API_KEY      = var.backend_api_key
  }

  tags = var.tags
}
