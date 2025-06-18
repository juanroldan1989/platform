variable "civo_token" {
  type = string
  description = "Civo API token for authentication"
}

variable "cluster_name" {
  type = string
  description = "Name of the Civo Kubernetes cluster"
}

variable "k3s_version" {
  type = string
  description = "Kubernetes Cluster version"
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
