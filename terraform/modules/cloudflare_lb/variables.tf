variable "cloudflare_api_token" {
  description = "Cloudflare API token with permissions to manage load balancers and pools."
  type        = string
}

variable "account_id" {
  description = "The ID of the Cloudflare account where the load balancer will be created."
  type        = string
}

variable "zone_id" {
  description = "The ID of the Cloudflare zone where the load balancer will be created."
  type        = string
}

variable "notification_email" {
  type        = string
  description = "Email address (comma-separated) to notify when the load balancer status changes."
}

variable "app_name" {
  description = "The name of the application for which the load balancer is being created."
  type        = string
}

variable "domain_name" {
  description = "The domain name for the load balancer."
  type        = string
}

variable "london_pool_address" {
  description = "The address of the London pool origin."
  type        = string
}

variable "frankfurt_pool_address" {
  description = "The address of the Frankfurt pool origin."
  type        = string
}
