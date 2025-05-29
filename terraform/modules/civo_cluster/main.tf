resource "civo_network" "cluster" {
  label = var.cluster_name
}

resource "civo_firewall" "cluster" {
  name                 = var.cluster_name
  network_id           = civo_network.cluster.id
  create_default_rules = true
}

resource "civo_kubernetes_cluster" "cluster" {
  name             = var.cluster_name
  write_kubeconfig = true
  network_id       = civo_network.cluster.id
  firewall_id      = civo_firewall.cluster.id

  pools {
    label      = "${var.cluster_name}-pool"
    size       = var.node_type
    node_count = tonumber(var.node_count)
  }
}

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
