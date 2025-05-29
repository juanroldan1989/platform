resource "vultr_kubernetes" "cluster" {
  region  = var.region
  label   = var.cluster_name
  version = "v1.33.0+1"

  node_pools {
    node_quantity = tonumber(var.node_count)
    plan          = var.node_type
    label         = "${var.cluster_name}-pool"
    auto_scaler   = true
    min_nodes     = var.min_nodes != "" ? tonumber(var.min_nodes) : 1
    max_nodes     = var.max_nodes != "" ? tonumber(var.max_nodes) : 3
  }
}

# Decode the kubeconfig YAML string into a map for safe access
locals {
  kubeconfig_raw = vultr_kubernetes.cluster.kube_config
  kubeconfig_json = yamldecode(local.kubeconfig_raw)
}

provider "kubernetes" {
  alias                  = "remote"
  host                   = try(local.kubeconfig_json["clusters"][0]["cluster"]["server"], "")
  client_certificate     = try(base64decode(local.kubeconfig_json["users"][0]["user"]["client-certificate-data"]), "")
  client_key             = try(base64decode(local.kubeconfig_json["users"][0]["user"]["client-key-data"]), "")
  cluster_ca_certificate = try(base64decode(local.kubeconfig_json["clusters"][0]["cluster"]["certificate-authority-data"]), "")
}

provider "kubernetes" {
  alias = "local"
}

resource "kubernetes_cluster_role_v1" "argocd_manager" {
  metadata {
    name = "argocd-manager-role"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    non_resource_urls = ["*"]
    verbs             = ["*"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "argocd_manager" {
  metadata {
    name = "argocd-manager-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.argocd_manager.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argocd_manager.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_service_account_v1" "argocd_manager" {
  metadata {
    name      = "argocd-manager"
    namespace = "kube-system"
  }
  secret {
    name = "argocd-manager-token"
  }
}

resource "kubernetes_secret_v1" "argocd_manager" {
  metadata {
    name      = "argocd-manager-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = "argocd-manager"
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [kubernetes_service_account_v1.argocd_manager]
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
    server           = local.kubeconfig_json["clusters"][0]["cluster"]["server"]
    clusterResources = "true"
    config = jsonencode({
      bearerToken     = kubernetes_secret_v1.argocd_manager.data.token
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

output "raw_kubeconfig" {
  value     = vultr_kubernetes.cluster.kube_config
  sensitive = true
}
