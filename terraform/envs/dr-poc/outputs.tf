output "acr_login_server" {
  value = module.acr.login_server
}

output "postgres_primary_fqdn" {
  value = module.postgres_primary.fqdn
}

output "postgres_replica_fqdn" {
  value = module.postgres_replica.fqdn
}

output "primary_ingress_ip" {
  value = azurerm_public_ip.primary_ingress.ip_address
}

output "secondary_ingress_ip" {
  value = azurerm_public_ip.secondary_ingress.ip_address
}

output "traffic_manager_fqdn" {
  value = module.traffic_manager.fqdn
}

output "aks_primary_name" {
  value = module.aks_primary.name
}

output "aks_secondary_name" {
  value = module.aks_secondary.name
}
