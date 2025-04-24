#!/bin/bash
set -euo pipefail

CLUSTER_NAME="mgmt-cluster"
ARGOCD_VERSION="v2.9.3"
CROSSPLANE_HELM_VERSION="1.14.2"
CROSSPLANE_NAMESPACE="crossplane-system"

# === Step 1: Create mgmt cluster using kind ===
echo "> Checking if mgmt cluster '$CLUSTER_NAME' already exists..."
if kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "✅ Cluster '$CLUSTER_NAME' already exists, skipping creation."
else
  echo "> Creating mgmt cluster..."
  kind create cluster --name "$CLUSTER_NAME"
fi

kubectl config use-context "kind-$CLUSTER_NAME"
echo "✅ Context switched to 'kind-$CLUSTER_NAME'"

# === Step 2: Create required namespaces ===
kubectl create namespace argocd || true
kubectl create namespace "$CROSSPLANE_NAMESPACE" || true

# === Step 3: Install ArgoCD ===
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml

# Wait for ArgoCD
kubectl rollout status deployment/argocd-server -n argocd

# === Step 4: Install ArgoCD CLI if missing ===
if ! command -v argocd &> /dev/null; then
  echo "🔧 Installing ArgoCD CLI..."
  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 || {
    echo "⚠️ Failed to write to /usr/local/bin — trying local install..."
    mkdir -p "$HOME/.local/bin"
    curl -sSL -o "$HOME/.local/bin/argocd" https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x "$HOME/.local/bin/argocd"
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  }
  chmod +x /usr/local/bin/argocd || true
fi

# === Step 5: Install Crossplane ===
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
if ! helm status crossplane -n "$CROSSPLANE_NAMESPACE" &> /dev/null; then
  helm install crossplane crossplane-stable/crossplane \
    --namespace "$CROSSPLANE_NAMESPACE" \
    --version "$CROSSPLANE_HELM_VERSION"
else
  echo "✅ Crossplane already installed in $CROSSPLANE_NAMESPACE"
fi

# Wait for Crossplane
kubectl rollout status deployment/crossplane -n "$CROSSPLANE_NAMESPACE"

# === Step 6: Install clusterctl (Cluster API CLI) if not installed ===
if ! command -v clusterctl &> /dev/null; then
  echo "📦 Installing clusterctl..."
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH="amd64"
  DEST="/usr/local/bin/clusterctl"
  TMP_DEST="/tmp/clusterctl"

  if [ "$(id -u)" -ne 0 ]; then
    mkdir -p "$HOME/.local/bin"
    DEST="$HOME/.local/bin/clusterctl"
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "⚠️ Running non-root — installing clusterctl to \$HOME/.local/bin"
  fi

  curl -L "https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-${OS}-${ARCH}" -o "$TMP_DEST"
  chmod +x "$TMP_DEST"
  mv "$TMP_DEST" "$DEST"
  echo "✅ clusterctl installed at $DEST"
else
  echo "✅ clusterctl already installed."
fi

# === Step 7: Initialize Cluster API with Docker infrastructure ===
if ! kubectl get ns capi-system &> /dev/null; then
  clusterctl init --infrastructure docker
else
  echo "✅ Cluster API already initialized."
fi

# === Final Output ===
echo "🎉 MGMT cluster setup complete with ArgoCD, Crossplane, and Cluster API."
echo "🔑 Access ArgoCD UI at https://localhost:8080 (if port-forwarded)"
echo "📘 Default ArgoCD login: admin / (password in argocd-initial-admin-secret)"
