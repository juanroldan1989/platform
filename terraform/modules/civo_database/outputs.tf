output "database_host" {
  description = "Database host endpoint"
  value       = civo_database.db.host
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

output "database_public_ipv4" {
  description = "Database public IPv4 address"
  value       = civo_database.db.public_ipv4
}

output "database_network_id" {
  description = "Default network ID used for database deployment (shared across clusters)"
  value       = local.database_network_id
}

output "database_firewall_id" {
  description = "Default firewall ID used for database deployment (shared across clusters)"
  value       = local.database_firewall_id
}

output "database_private_ipv4" {
  description = "Database private IPv4 address"
  value       = civo_database.db.private_ipv4
}
