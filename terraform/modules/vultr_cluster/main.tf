resource "vultr_kubernetes" "cluster" {
  region          = var.region
  label           = var.cluster_name
  version         = "v1.33.0+1"
  enable_firewall = true

  node_pools {
    node_quantity = tonumber(var.node_count)
    plan          = var.node_type
    label         = "${var.cluster_name}-pool"
    auto_scaler   = true
    min_nodes     = var.min_nodes != "" ? tonumber(var.min_nodes) : 1
    max_nodes     = var.max_nodes != "" ? tonumber(var.max_nodes) : 3
  }
}

resource "vultr_firewall_rule" "http" {
  firewall_group_id = vultr_kubernetes.cluster.firewall_group_id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "80"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  notes             = "Allow Public HTTP access (e.g.: Ingress, Apps)"
}

resource "vultr_firewall_rule" "https" {
  firewall_group_id = vultr_kubernetes.cluster.firewall_group_id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "443"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  notes             = "Allow Public HTTPS access"
}

resource "vultr_firewall_rule" "k8s_api" {
  firewall_group_id = vultr_kubernetes.cluster.firewall_group_id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "6443"
  subnet            = var.my_public_ip_subnet
  subnet_size       = var.my_public_ip_subnet_size
  notes             = "Allow Secure Access to Kubernetes API (e.g.: ArgoCD, kubectl)"
}

resource "vultr_firewall_rule" "ssh" {
  firewall_group_id = vultr_kubernetes.cluster.firewall_group_id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "22"
  subnet            = var.my_public_ip_subnet
  subnet_size       = var.my_public_ip_subnet_size
  notes             = "Allow SSH access (e.g.: debugging, maintenance)"
}

resource "vultr_firewall_rule" "egress" {
  firewall_group_id = vultr_kubernetes.cluster.firewall_group_id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "1-65535"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  notes             = "Allow all outbound traffic (e.g.: pulling container images, APIs)"
}

# https://registry.terraform.io/providers/vultr/vultr/latest/docs/resources/kubernetes#kube_config-1
# The kube_config attribute is a *base64-encoded* string containing the `kubeconfig` file for the Kubernetes cluster.
locals {
  kubeconfig_raw  = base64decode(vultr_kubernetes.cluster.kube_config)
  kubeconfig_json = yamldecode(local.kubeconfig_raw)
}

provider "kubernetes" {
  alias                  = "remote" # This provider is used to interact with the Vultr Kubernetes cluster.
  host                   = try(local.kubeconfig_json["clusters"][0]["cluster"]["server"], "")
  client_certificate     = try(base64decode(local.kubeconfig_json["users"][0]["user"]["client-certificate-data"]), "")
  client_key             = try(base64decode(local.kubeconfig_json["users"][0]["user"]["client-key-data"]), "")
  cluster_ca_certificate = try(base64decode(local.kubeconfig_json["clusters"][0]["cluster"]["certificate-authority-data"]), "")
}

provider "kubernetes" {
  alias = "local" # This provider is used to interact with the local Kubernetes cluster (e.g., `mgmt-cluster` -> ArgoCD).
}

# This secret registers the `Vultr` cluster with ArgoCD.
# It uses the `kubeconfig` data from the `Vultr` Kubernetes resource.
resource "kubernetes_secret_v1" "argocd_cluster_secret" {
  provider = kubernetes.local
  metadata {
    name      = var.cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  data = {
    name             = var.cluster_name
    server           = local.kubeconfig_json["clusters"][0]["cluster"]["server"]
    clusterResources = "true"
    config = jsonencode({
      # Argocd uses Vultr's `kubeconfig` data to authenticate with the Vultr Kubernetes cluster.
      tlsClientConfig = {
        insecure = false
        caData   = local.kubeconfig_json["clusters"][0]["cluster"]["certificate-authority-data"]
        certData = local.kubeconfig_json["users"][0]["user"]["client-certificate-data"]
        keyData  = local.kubeconfig_json["users"][0]["user"]["client-key-data"]
      }
    })
  }
  type = "Opaque"
}

# Raw `kubeconfig` for debugging or local access
# This tells Terraform to decode the base64 string before injecting it into the data.kubeconfig field
# which then gets base64-encoded once more by Kubernetes (as all secret values are).
resource "kubernetes_secret_v1" "cluster_secret" {
  provider = kubernetes.local
  metadata {
    name      = "${var.cluster_name}-kubeconfig"
    namespace = "argocd"
  }
  data = {
    kubeconfig = base64decode(vultr_kubernetes.cluster.kube_config)
  }
  type = "Opaque"
}
