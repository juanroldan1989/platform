output "database_host" {
  description = "Database host endpoint"
  value       = civo_database.db.endpoint
}

output "database_port" {
  description = "Database port"
  value       = civo_database.db.port
}

output "database_name" {
  description = "Database name"
  value       = civo_database.db.name
}

output "database_username" {
  description = "Database username"
  value       = civo_database.db.username
}

output "database_dns_endpoint" {
  description = "Database DNS endpoint"
  value       = civo_database.db.dns_endpoint
}
