variable "civo_token" {
  description = "Civo API token for authentication"
  type = string
}

variable "cluster_name" {
  description = "Name of the Civo Kubernetes cluster"
  type = string
}

variable "k8s_version" {
  description = "Kubernetes Cluster version"
  type = string
}

variable "node_count" {
  description = "Number of nodes in the Civo Kubernetes cluster"
  type = string
}

variable "node_type" {
  description = "Type of nodes in the Civo Kubernetes cluster"
  type    = string
  default = "g4s.kube.medium"
}
