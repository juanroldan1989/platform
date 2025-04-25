#!/bin/bash

set -euo pipefail

WORKLOAD_CLUSTERS=("dev-cluster" "prod-cluster" "test-cluster")
NAMESPACE="default"

echo "⚠️  Force deleting workload clusters and their resources..."

for CLUSTER in "${WORKLOAD_CLUSTERS[@]}"; do
  echo ""
  echo "🔍 Checking resources for workload cluster: $CLUSTER"

  # Check if cluster still exists
  if ! kubectl get cluster "$CLUSTER" -n "$NAMESPACE" &> /dev/null; then
    echo "✅ Cluster '$CLUSTER' already deleted or not found, skipping."
  else
    echo "⚠️  Removing finalizers if any (cluster, control plane, infra)"

    # Remove finalizers from main cluster object
    kubectl patch cluster "$CLUSTER" -n "$NAMESPACE" --type=merge -p '{"metadata":{"finalizers":[]}}' || true

    # Remove finalizers from DockerCluster
    kubectl patch dockercluster "$CLUSTER" -n "$NAMESPACE" --type=merge -p '{"metadata":{"finalizers":[]}}' || true

    # Remove finalizers from KubeadmControlPlane
    kubectl patch kubeadmcontrolplane "$CLUSTER-control-plane" -n "$NAMESPACE" --type=merge -p '{"metadata":{"finalizers":[]}}' || true

    echo "🗑️  Deleting cluster and related resources for: $CLUSTER"

    kubectl delete cluster "$CLUSTER" -n "$NAMESPACE" --ignore-not-found=true || true
    kubectl delete dockercluster "$CLUSTER" -n "$NAMESPACE" --ignore-not-found=true || true
    kubectl delete kubeadmcontrolplane "$CLUSTER-control-plane" -n "$NAMESPACE" --ignore-not-found=true || true
    kubectl delete dockermachinetemplate "$CLUSTER-control-plane" -n "$NAMESPACE" --ignore-not-found=true || true
  fi

  echo "🐳 Cleaning up any orphaned Docker containers for: $CLUSTER"
  docker ps -a --filter "name=${CLUSTER}" --format "{{.ID}}" | xargs -r docker rm -f || true
done

echo ""
echo "✅ Done. All workload clusters cleaned up (or already deleted)."
