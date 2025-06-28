provider "http" {}

data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

locals {
  mgmt_cluster_public_ip_cidr = "${trimspace(data.http.my_public_ip.response_body)}/32"
}

resource "civo_network" "cluster" {
  label = var.cluster_name
}

resource "civo_firewall" "cluster" {
  name                 = var.cluster_name
  network_id           = civo_network.cluster.id
  create_default_rules = false # `false` when custom rules are applied

  ingress_rule {
    label      = "http"
    protocol   = "tcp"
    port_range = "80"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }

  ingress_rule {
    label      = "https"
    protocol   = "tcp"
    port_range = "443"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }

  ingress_rule {
    label      = "allow-k8s-api" # access to Kubernetes API server (e.g.: ArgoCD)
    protocol   = "tcp"
    port_range = "6443"
    cidr       = [local.mgmt_cluster_public_ip_cidr]
    action     = "allow"
  }

  ingress_rule {
    label      = "ssh"
    protocol   = "tcp"
    port_range = "22"
    cidr       = [local.mgmt_cluster_public_ip_cidr]
    action     = "allow"
  }

  egress_rule {
    label      = "all"
    protocol   = "tcp"
    port_range = "1-65535"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }
}

resource "civo_kubernetes_cluster" "cluster" {
  name               = var.cluster_name
  write_kubeconfig   = true
  network_id         = civo_network.cluster.id
  firewall_id        = civo_firewall.cluster.id
  kubernetes_version = var.k8s_version

  pools {
    label      = "${var.cluster_name}-pool"
    size       = var.node_type
    node_count = tonumber(var.node_count)
  }
}

# https://registry.terraform.io/providers/civo/civo/latest/docs/resources/kubernetes_cluster#kubeconfig-3
# The kube_config attribute is a *string* containing the `kubeconfig` file for the Kubernetes cluster.
locals {
  kubeconfig_raw  = civo_kubernetes_cluster.cluster.kubeconfig
  kubeconfig_json = yamldecode(local.kubeconfig_raw)
}

provider "kubernetes" {
  host                   = civo_kubernetes_cluster.cluster.api_endpoint
  client_certificate     = try(base64decode(local.kubeconfig_json["users"][0]["user"]["client-certificate-data"]), "")
  client_key             = try(base64decode(local.kubeconfig_json["users"][0]["user"]["client-key-data"]), "")
  cluster_ca_certificate = try(base64decode(local.kubeconfig_json["clusters"][0]["cluster"]["certificate-authority-data"]), "")
}

provider "kubernetes" {
  alias = "local"
}

# This secret registers the `CIVO` cluster with ArgoCD.
# It uses the `kubeconfig` data from the `CIVO` Kubernetes resource.
resource "kubernetes_secret_v1" "argocd_cluster_secret" {
  provider = kubernetes.local
  metadata {
    name      = var.cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "workload"                       = "true"
      "cluster"                        = var.cluster_name
    }
  }
  data = {
    name             = var.cluster_name
    server           = civo_kubernetes_cluster.cluster.api_endpoint
    clusterResources = "true"
    config = jsonencode({
      # Argocd uses Civo's `kubeconfig` data to authenticate with the Civo Kubernetes cluster.
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

# Optional: raw kubeconfig for later admin access (not used by ArgoCD)
resource "kubernetes_secret_v1" "cluster_secret" {
  provider = kubernetes.local
  metadata {
    name      = "${var.cluster_name}-kubeconfig"
    namespace = "argocd"
  }
  data = {
    kubeconfig = civo_kubernetes_cluster.cluster.kubeconfig
  }
  type = "Opaque"
}

output "raw_kubeconfig" {
  value     = civo_kubernetes_cluster.cluster.kubeconfig
  sensitive = true
}

# Fetches aws-creds secrets content from mgmt-cluster
data "kubernetes_secret" "aws_creds" {
  provider = kubernetes.local
  metadata {
    name      = "aws-creds"
    namespace = "external-secrets"
  }
}

# Writes AWS Credentials required for ESO (External Secrets Operator) in new cluster
resource "kubernetes_namespace_v1" "external_secrets" {
  provider = kubernetes
  metadata {
    name = "external-secrets"
  }
}

resource "kubernetes_secret_v1" "aws_creds" {
  provider = kubernetes
  metadata {
    name      = "aws-creds"
    namespace = "external-secrets"
  }

  data = {
    access-key        = data.kubernetes_secret.aws_creds.data["access-key"]
    secret-access-key = data.kubernetes_secret.aws_creds.data["secret-access-key"]
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace_v1.external_secrets
  ]
}
