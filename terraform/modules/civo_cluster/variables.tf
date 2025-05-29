variable "civo_token" {
  type = string
  description = "Civo API token for authentication"
}

variable "cluster_name" {
  type = string
  description = "Name of the Civo Kubernetes cluster"
}

variable "node_count" {
  type = string
  description = "Number of nodes in the Civo Kubernetes cluster"
}

variable "node_type" {
  type    = string
  description = "Type of nodes in the Civo Kubernetes cluster"
  default = "g4s.kube.medium"
}

# TODO: Remove or replace with ArgoCD egress IP once GitOps setup is stable
variable "my_public_ip_cidr" {
  type        = string
  description = "Your public IP address in CIDR notation"
  default     = "80.56.186.251/32"
}
