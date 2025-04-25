#!/bin/bash
set -euo pipefail

MGMT_CONTAINER="mgmt-cluster-control-plane"     # Name of the management cluster control plane container
MGMT_CONTAINER_TARGET_DIR="/etc/kubernetes"     # Target directory in the management cluster control plane container
MGMT_CONTAINER_ARGOCD_SERVER="10.96.48.73:443" # argocd-server service IP address

WORKLOAD_CLUSTERS="$(kubectl get clusters -o jsonpath='{.items[*].metadata.name}')"

if [ -z "$WORKLOAD_CLUSTERS" ]; then
  echo "❌ No workload clusters found. Please create them first."
  exit 1
fi

echo "🚀 Registering workload clusters..."
for cluster in $WORKLOAD_CLUSTERS; do
  echo "🔑 Generating kubeconfig for workload cluster: $cluster"
  kubectl get secret "$cluster"-kubeconfig -o jsonpath='{.data.value}' | base64 --decode > /tmp/"$cluster".kubeconfig
  echo "✅ Kubeconfig for workload cluster '$cluster' generated."
done

for cluster in $WORKLOAD_CLUSTERS; do
  echo "📦 Copying kubeconfig for workload cluster '$cluster' to management cluster control plane container..."
  docker cp /tmp/"$cluster".kubeconfig "$MGMT_CONTAINER":"$MGMT_CONTAINER_TARGET_DIR"/"$cluster".kubeconfig
  echo "✅ Kubeconfig for workload cluster '$cluster' copied."
done

echo " 🔗 Connecting to management cluster control plane and registering workload clusters with ArgoCD..."
docker exec -i "$MGMT_CONTAINER" bash -c "
  set -euo pipefail

  echo \"📦 Download ArgoCD CLI if not already installed\"
  if ! command -v argocd &> /dev/null; then
    echo \"🔧 Installing ArgoCD CLI...\"
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
  fi

  export ARGOCD_PASSWORD=\$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode)
  argocd login $MGMT_CONTAINER_ARGOCD_SERVER --username admin --password \"\$ARGOCD_PASSWORD\" --insecure

  for kubeconfig in ${MGMT_CONTAINER_TARGET_DIR}/*-cluster.kubeconfig; do
    CLUSTER_NAME=\$(basename \"\$kubeconfig\" | sed 's/\.kubeconfig//')

    echo \"🔗 Registering cluster \$CLUSTER_NAME...\"
    export KUBECONFIG=\"\$kubeconfig\"
    CONTEXT=\"\${CLUSTER_NAME}-admin@\${CLUSTER_NAME}\"

    # Add the cluster with a nice name
    if argocd cluster add \"\$CONTEXT\" --yes --name \"\$CLUSTER_NAME\" --upsert; then
      echo \"✅ Registered \$CLUSTER_NAME with ArgoCD\"
    else
      echo \"⚠️ Failed to register \$CLUSTER_NAME\"
    fi
  done
"

echo "🏷️ Applying environment labels to ArgoCD cluster secrets..."
for secret in $(kubectl get secrets -n argocd -l "argocd.argoproj.io/secret-type=cluster" -o jsonpath="{.items[*].metadata.name}"); do
  FRIENDLY_NAME=$(kubectl get secret "$secret" -n argocd -o jsonpath="{.data.name}" | base64 --decode)

  echo "🏷️ Processing secret: $secret (cluster name: $FRIENDLY_NAME)"
  case "$FRIENDLY_NAME" in
    dev-cluster)
      kubectl label secret "$secret" -n argocd environment=dev workload-deploy=enabled --overwrite
      ;;
    test-cluster)
      kubectl label secret "$secret" -n argocd environment=test workload-deploy=enabled --overwrite
      ;;
    prod-cluster)
      kubectl label secret "$secret" -n argocd environment=prod workload-deploy=enabled --overwrite
      ;;
    *)
      echo "⚠️ Unknown cluster name '$FRIENDLY_NAME', skipping label."
      ;;
  esac
done

echo "✅ All cluster secrets labeled!"

echo "📋 Current registered workload clusters:
$(docker exec -i "$MGMT_CONTAINER" bash -c "argocd cluster list")"

echo "🚀 Workload clusters registered successfully."
