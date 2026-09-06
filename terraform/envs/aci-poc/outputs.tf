output "frontend_url" {
  value = module.app.frontend_url
}

output "backend_url" {
  value = module.app.backend_url
}

output "backend_docs_url" {
  value = module.app.backend_docs_url
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "postgres_fqdn" {
  value = module.postgres.fqdn
}
