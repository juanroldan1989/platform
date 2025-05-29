variable "vultr_token" {
  type        = string
  description = "API token to authenticate with the Vultr provider"
}

variable "region" {
  type        = string
  description = "Vultr region to deploy the cluster (e.g. 'ewr', 'sjc')"
  default     = "ewr"
}

variable "cluster_name" {
  type        = string
  description = "Unique name to label the cluster and associated resources"
}

variable "node_count" {
  type        = string
  description = "Number of nodes in the initial node pool"
}

variable "node_type" {
  type        = string
  description = "Vultr node plan (e.g. vc2-2c-4gb)"
  default     = "vc2-2c-4gb"
}

variable "min_nodes" {
  type        = string
  description = "Minimum number of nodes for autoscaler"
  default     = "1"
}

variable "max_nodes" {
  type        = string
  description = "Maximum number of nodes for autoscaler"
  default     = "3"
}

# TODO: Remove or replace with ArgoCD egress IP once GitOps setup is stable
variable "my_public_ip_subnet" {
  type        = string
  description = "Your public IP address subnet"
  default     = "80.56.186.251"
}

variable "my_public_ip_subnet_size" {
  type        = number
  description = "Size of your public IP address subnet"
  default     = 32
}
