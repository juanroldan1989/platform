#!/bin/bash
set -euo pipefail

CLUSTERS_PATH="clusters-inventories"
MGMT_CONTAINER="mgmt-cluster-control-plane"     # Name of the management cluster control plane container
MGMT_CONTAINER_TARGET_DIR="/etc/kubernetes"     # Target directory in the management cluster control plane container

if [ ! -d "$CLUSTERS_PATH" ]; then
  echo "❌ Directory '$CLUSTERS_PATH' not found. Please create it and add Cluster YAMLs."
  exit 1
fi

# === Ensure openssl is installed ===
if ! command -v openssl &> /dev/null; then
  echo "❌ 'openssl' is required but not installed."
  exit 1
fi

# Loop through cluster folders and apply resources in dependency order
for cluster_dir in "$CLUSTERS_PATH"/*; do
  if [[ -d "$cluster_dir" ]]; then

    CLUSTER_NAME=$(grep "name:" "$cluster_dir/cluster.yaml" | awk '{print $2}' | head -n 1)
    if [[ -z "$CLUSTER_NAME" ]]; then
      echo "⚠️ Skipping $cluster_dir — no Cluster definition found"
      continue
    fi

    echo "> Checking status of workload cluster: $CLUSTER_NAME"

    if kubectl get cluster "$CLUSTER_NAME" &> /dev/null; then
      echo "✅ Workload cluster '$CLUSTER_NAME' already exists. Skipping creation."
    else
      echo "🚀 Creating workload cluster '$CLUSTER_NAME' from $cluster_dir"
      kubectl apply -f "$cluster_dir"/infra.yaml
      kubectl apply -f "$cluster_dir"/control-plane.yaml
      kubectl apply -f "$cluster_dir"/cluster.yaml
    fi
  fi
done

# Wait for all clusters to be ready
for cluster_dir in "$CLUSTERS_PATH"/*; do
  if [[ -d "$cluster_dir" ]]; then

    CLUSTER_NAME=$(grep "name:" "$cluster_dir/cluster.yaml" | awk '{print $2}' | head -n 1)
    if [[ -z "$CLUSTER_NAME" ]]; then
      echo "⚠️ Skipping $cluster_dir — no Cluster definition found"
      continue
    fi

    echo "⏳ Waiting for workload cluster '$CLUSTER_NAME' to become ready..."
    kubectl wait --for=condition=Ready clusters "$CLUSTER_NAME" --timeout=5m || {
      echo "⚠️ Cluster '$CLUSTER_NAME' did not become ready in time."
    }
  fi
done

# === Fetch CA cert and create Secrets ===
for cluster_dir in "$CLUSTERS_PATH"/*; do
  if [[ -d "$cluster_dir" ]]; then

    CLUSTER_NAME=$(grep "name:" "$cluster_dir/cluster.yaml" | awk '{print $2}' | head -n 1)
    if [[ -z "$CLUSTER_NAME" ]]; then
      echo "⚠️ Skipping $cluster_dir — no Cluster definition found"
      continue
    fi

    echo "📥 Fetching CA cert for $CLUSTER_NAME..."

    CONTROL_PLANE_CONTAINER=$(docker ps --filter "name=${CLUSTER_NAME}-control-plane" --format "{{.Names}}")

    if [[ -z "$CONTROL_PLANE_CONTAINER" ]]; then
      echo "❌ Could not find control-plane container for $CLUSTER_NAME"
      exit 1
    fi

    docker cp "${CONTROL_PLANE_CONTAINER}:/etc/kubernetes/pki/ca.crt" "/tmp/${CLUSTER_NAME}-ca.crt"

    echo "🔐 Creating secret for CA cert..."
    kubectl create secret generic "${CLUSTER_NAME}-ca" \
      --namespace default \
      --from-file=ca.crt="/tmp/${CLUSTER_NAME}-ca.crt" \
      --dry-run=client -o yaml | kubectl apply -f -

    echo "✅ Secret '${CLUSTER_NAME}-ca' created."
  fi
done

echo "🚀 Generating kubeconfig values for workload clusters"
for cluster_dir in "$CLUSTERS_PATH"/*; do

  CLUSTER_NAME=$(grep "name:" "$cluster_dir/cluster.yaml" | awk '{print $2}' | head -n 1)
  if [[ -z "$CLUSTER_NAME" ]]; then
    echo "⚠️ Skipping $cluster_dir — no Cluster definition found"
    continue
  fi

  echo "🔑 Generating kubeconfig for workload cluster: $CLUSTER_NAME"
  kubectl get secret "$CLUSTER_NAME"-kubeconfig -o jsonpath='{.data.value}' | base64 --decode > /tmp/"$CLUSTER_NAME".kubeconfig
  echo "✅ Kubeconfig for workload cluster '$CLUSTER_NAME' generated."
  echo "📦 Copying kubeconfig for workload cluster '$CLUSTER_NAME' to management cluster control plane container..."
  docker cp /tmp/"$CLUSTER_NAME".kubeconfig "$MGMT_CONTAINER":"$MGMT_CONTAINER_TARGET_DIR"/"$CLUSTER_NAME".kubeconfig
  echo "✅ Kubeconfig for workload cluster '$CLUSTER_NAME' copied."
done

# === Create Bootstrap Tokens for joining workers ===
for cluster_dir in "$CLUSTERS_PATH"/*; do
  if [[ -d "$cluster_dir" ]]; then

    CLUSTER_NAME=$(grep "name:" "$cluster_dir/cluster.yaml" | awk '{print $2}' | head -n 1)
    if [[ -z "$CLUSTER_NAME" ]]; then
      echo "⚠️ Skipping $cluster_dir — no Cluster definition found"
      continue
    fi

    echo "🔑 Creating Bootstrap Token in workload cluster: $CLUSTER_NAME..."

    # Generate random token
    TOKEN_ID=$(openssl rand -hex 3)
    TOKEN_SECRET=$(openssl rand -hex 8)

    echo "🎲 Token ID: $TOKEN_ID"
    echo "🎲 Token Secret: $TOKEN_SECRET"

    # Path to kubeconfig
    KUBECONFIG_PATH="/etc/kubernetes/${CLUSTER_NAME}.kubeconfig"

    # Create BootstrapToken Secret inside the workload cluster
    docker exec mgmt-cluster-control-plane kubectl --kubeconfig="${KUBECONFIG_PATH}" -n kube-system create secret generic "bootstrap-token-${TOKEN_ID}" \
      --type 'bootstrap.kubernetes.io/token' \
      --from-literal=token-id="${TOKEN_ID}" \
      --from-literal=token-secret="${TOKEN_SECRET}" \
      --from-literal=usage-bootstrap-authentication=true \
      --from-literal=usage-bootstrap-signing=true \
      --from-literal=auth-extra-groups=system:bootstrappers:worker,system:bootstrappers

    echo "✅ Bootstrap Token created for cluster: $CLUSTER_NAME"

    echo "🌐 Installing Calico CNI in workload cluster: $CLUSTER_NAME..."
    docker exec mgmt-cluster-control-plane kubectl --kubeconfig="/etc/kubernetes/${CLUSTER_NAME}.kubeconfig" apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
    echo "✅ Calico CNI installed for cluster: $CLUSTER_NAME"
  fi
done

# === Force kubeadm join on each worker node (md-* prefix) ===
for container_id in $(docker ps --format '{{.Names}}' | grep md-0); do
  echo "🔧 Forcing kubeadm join inside container: $container_id ..."
  docker exec "$container_id" kubeadm join --config /run/kubeadm/kubeadm-join-config.yaml --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt
done

# Show the registered CAPI clusters
echo "📋 Current Cluster API managed workload clusters:"
kubectl get clusters
