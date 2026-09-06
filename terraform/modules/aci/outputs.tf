output "fqdn" {
  value = local.fqdn
}

output "frontend_url" {
  value = "http://${local.fqdn}:8080"
}

output "backend_url" {
  value = "http://${local.fqdn}:8000"
}

output "backend_docs_url" {
  value = "http://${local.fqdn}:8000/docs"
}
