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

resource "civo_database" "db" {
  name    = var.database_name
  size    = var.database_size
  engine  = "mysql"
  version = var.mysql_version
  nodes   = var.nodes
  region  = var.region

  # Let CIVO use default network and firewall if not specified
  # This ensures shared access across clusters in the same region
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
    host     = civo_database.db.endpoint
    port     = civo_database.db.port
    database = var.database_name
    # Connection string for applications
    connection_string = "mysql://${civo_database.db.username}:${civo_database.db.password}@${civo_database.db.endpoint}:${civo_database.db.port}/${var.database_name}"
  }

  type = "Opaque"
}
