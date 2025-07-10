# CIVO Managed Database Module - Phase 3: Shared Database
#
# This module creates a managed MySQL database in CIVO that can be accessed
# by multiple Kubernetes clusters. It uses the default CIVO network and firewall
# to enable shared access across all clusters in the same region.
#
# Phase 3 Benefits:
# - Single source of truth for data
# - No data drift between clusters
# - Built-in high availability
# - Data persists even if clusters go down
# - Centralized database management

# Data source to get the default network in the region
data "civo_network" "default" {
  label  = "Default"
  region = var.region
}

# Data source to get the default firewall in the region
data "civo_firewall" "default" {
  name   = "default"
  region = var.region
}

locals {
  # Use default network and firewall for shared database access across clusters
  database_network_id  = data.civo_network.default.id
  database_firewall_id = data.civo_firewall.default.id
}

resource "civo_database" "db" {
  name    = var.database_name
  size    = var.database_size
  engine  = "mysql"
  version = var.mysql_version
  nodes   = var.nodes
  region  = var.region

  # Network and firewall configuration - use default/shared infrastructure
  firewall_id = local.database_firewall_id
  network_id  = local.database_network_id
}

# Create a Kubernetes secret with database credentials (for mgmt cluster use)
resource "kubernetes_secret" "blog_database_creds" {
  metadata {
    name      = "blog-db-managed-creds"
    namespace = var.target_namespace
  }

  data = {
    username = civo_database.db.username
    password = civo_database.db.password
    host     = civo_database.db.host
    port     = civo_database.db.port
    database = var.database_name
    # Connection string for applications
    connection_string = "mysql://${civo_database.db.username}:${civo_database.db.password}@${civo_database.db.host}:${civo_database.db.port}/${var.database_name}"
  }

  type = "Opaque"
}

# Store database credentials in AWS Secrets Manager for cross-cluster access
resource "aws_secretsmanager_secret" "blog_database_creds" {
  name                    = "civo/blog-database-credentials"
  description             = "Blog database credentials for CIVO managed database"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "blog_database_creds" {
  secret_id = aws_secretsmanager_secret.blog_database_creds.id
  secret_string = jsonencode({
    username          = civo_database.db.username
    password          = civo_database.db.password
    host              = civo_database.db.host
    port              = civo_database.db.port
    database          = var.database_name
    connection_string = "mysql://${civo_database.db.username}:${civo_database.db.password}@${civo_database.db.host}:${civo_database.db.port}/${var.database_name}"
  })
}
