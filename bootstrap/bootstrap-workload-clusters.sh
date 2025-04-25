#!/bin/bash
set -euo pipefail

CLUSTERS_PATH="clusters-inventories"

if [ ! -d "$CLUSTERS_PATH" ]; then
  echo "❌ Directory '$CLUSTERS_PATH' not found. Please create it and add Cluster YAMLs."
  exit 1
fi

# === Ensure yq is installed ===
if ! command -v yq &> /dev/null; then
  echo "❌ 'yq' is required but not installed. Please install: https://github.com/mikefarah/yq"
  exit 1
fi

# Loop through cluster folders and apply resources in dependency order
for cluster_dir in "$CLUSTERS_PATH"/*; do
  if [[ -d "$cluster_dir" ]]; then
    CLUSTER_NAME=$(yq e 'select(.kind == "Cluster") | .metadata.name' "$cluster_dir"/cluster.yaml)
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
    CLUSTER_NAME=$(yq e 'select(.kind == "Cluster") | .metadata.name' "$cluster_dir"/cluster.yaml)
    if [[ -z "$CLUSTER_NAME" ]]; then
      continue
    fi
    echo "⏳ Waiting for workload cluster '$CLUSTER_NAME' to become ready..."
    kubectl wait --for=condition=Ready clusters "$CLUSTER_NAME" --timeout=5m || {
      echo "⚠️ Cluster '$CLUSTER_NAME' did not become ready in time."
    }
  fi
done

# Show the registered CAPI clusters
echo "📋 Current Cluster API managed workload clusters:"
kubectl get clusters
