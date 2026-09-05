output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "kubelet_identity_object_id" {
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  description = "Used to grant AcrPull on the shared ACR."
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
  description = "Reserved for future workload-identity federation; OIDC issuer is not enabled by default in this POC module."
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}
