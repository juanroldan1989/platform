variable "civo_token" {
  description = "Civo API token for authentication"
  type        = string
}

variable "region" {
  description = "CIVO region where to create the database"
  type        = string
}

variable "database_name" {
  description = "Name of the Civo managed database instance"
  type        = string
}

variable "connection_database_name" {
  description = "Name of the database/catalog applications should connect to"
  type        = string
  default     = "postgres"
}

variable "database_size" {
  description = "Size of the database (g3.db.small, g3.db.medium, g3.db.large)"
  type        = string
  default     = "g3.db.small"
}

variable "database_engine" {
  description = "Database engine"
  type        = string
  default     = "PostgreSQL"
}

variable "database_version" {
  description = "Database engine version"
  type        = string
  default     = "17"
}

variable "database_username" {
  description = "Database username"
  type        = string
  default     = "blog"
}

variable "target_namespace" {
  description = "Kubernetes namespace where to create the secret with database credentials"
  type        = string
}

variable "nodes" {
  description = "Number of database nodes"
  type        = number
  default     = 1
}
