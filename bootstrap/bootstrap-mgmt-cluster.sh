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
  kind create cluster --name "$CLUSTER_NAME" --config bootstrap/mgmt-cluster-config.yaml
fi

kubectl config use-context "kind-$CLUSTER_NAME"
echo "✅ Context switched to 'kind-$CLUSTER_NAME'"

# === Step 2: Create required namespaces ===
kubectl create namespace argocd || true
kubectl create namespace "$CROSSPLANE_NAMESPACE" || true

# === Step 3: Install ArgoCD ===
echo "> Installing ArgoCD via Helm"
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

if ! kubectl get pods -n argocd | grep -q argocd-server; then
  helm install argocd argo/argo-cd --namespace argocd --create-namespace
else
  echo "➡️ ArgoCD already installed, skipping..."
fi

# Wait for ArgoCD
kubectl rollout status deployment/argocd-server -n argocd

# === Step 4: Ensure ArgoCD CLI is available ===
if ! command -v argocd &> /dev/null; then
  echo "🔧 Installing ArgoCD CLI..."
  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /usr/local/bin/argocd
fi

# === Step 5: Allow ArgoCD to fetch manifests from GitHub ===
if [[ -n "${PERSONAL_ACCESS_TOKEN:-}" ]]; then
  echo "🔐 GitHub token detected — configuring ArgoCD repo access"

  echo "🔁 Port-forwarding ArgoCD server in the background..."
  kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
  PF_PID=$!

  echo "⏳ Waiting for ArgoCD server pod to be Ready..."
  for i in {1..30}; do
    READY=$(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath="{.items[0].status.containerStatuses[0].ready}" 2>/dev/null || echo "false")
    if [[ "$READY" == "true" ]]; then
      echo "✅ ArgoCD server pod is Ready"
      break
    fi
    echo "⌛ ArgoCD server not ready yet, retrying... ($i/30)"
    sleep 5
  done

  echo "🔑 Fetching ArgoCD admin password from Kubernetes secret..."
  export ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)

  echo "🔐 Logging into ArgoCD CLI via localhost..."
  argocd login localhost:8080 \
    --username admin \
    --password "$ARGOCD_PASSWORD" \
    --insecure

  echo "🔎 Checking if repo is already registered..."
  if ! argocd repo list | grep -q 'platform'; then
    echo "📥 Registering repo with ArgoCD..."
    argocd repo add https://github.com/juanroldan1989/platform \
      --username juanroldan1989 \
      --password "$PERSONAL_ACCESS_TOKEN" \
      --type git
  else
    echo "✅ Repo already registered"
  fi

  echo "🛑 Cleaning up port-forward (PID: $PF_PID)..."
  # kill $PF_PID
else
  echo "✅ Skipping ArgoCD repo registration — no GitHub token provided"
fi

# === Step 6: Install Crossplane ===
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

# === Step 7: Install clusterctl (Cluster API CLI) if not installed ===
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

# === Step 8: Initialize Cluster API with Docker infrastructure ===
if ! kubectl get ns capi-system &> /dev/null; then
  clusterctl init --infrastructure docker
else
  echo "✅ Cluster API already initialized."
fi

# === Final Output ===
echo "🎉 MGMT cluster setup complete with ArgoCD, Crossplane, and Cluster API."
echo "🔑 Access ArgoCD UI at https://localhost:8080 (if port-forwarded)"

# === Argocd UI Login ===
echo "📘 Default ArgoCD login: admin"
echo "🔑 ArgoCD admin password: $ARGOCD_PASSWORD"
echo "🔗 ArgoCD server port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "🔗 ArgoCD server URL: https://localhost:8080"
