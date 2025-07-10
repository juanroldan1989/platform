variable "database_name" {
  description = "Name of the database"
  type        = string
}

variable "database_size" {
  description = "Size of the database (g3.db.small, g3.db.medium, g3.db.large)"
  type        = string
  default     = "g3.db.small"
}

variable "mysql_version" {
  description = "MySQL version"
  type        = string
  default     = "8.0"
}

variable "database_username" {
  description = "Database username"
  type        = string
  default     = "ghost"
}

variable "target_namespace" {
  description = "Kubernetes namespace where to create the secret with database credentials"
  type        = string
}

variable "region" {
  description = "CIVO region where to create the database"
  type        = string
}

variable "nodes" {
  description = "Number of database nodes"
  type        = number
  default     = 1
}
