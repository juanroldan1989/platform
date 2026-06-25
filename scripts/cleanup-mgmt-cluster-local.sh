#!/bin/bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-mgmt-cluster}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-1800}"
DELETE_K3D_CLUSTER=true

usage() {
  cat <<EOF
Usage: $0 --confirm [--skip-k3d]

Deletes GitOps-managed workload apps, load balancers, databases, workload clusters,
then deletes the local k3d management cluster.

Options:
  --confirm   Required. Prevents accidental cloud resource deletion.
  --skip-k3d  Leave the local k3d management cluster running after cloud teardown.
EOF
}

CONFIRMED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm)
      CONFIRMED=true
      shift
      ;;
    --skip-k3d)
      DELETE_K3D_CLUSTER=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "${CONFIRMED}" != "true" ]]; then
  usage
  exit 1
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_command kubectl
require_command k3d

delete_app() {
  local name="$1"
  kubectl -n "${ARGOCD_NAMESPACE}" delete application "${name}" --ignore-not-found --wait=false
}

delete_appset() {
  local name="$1"
  kubectl -n "${ARGOCD_NAMESPACE}" delete applicationset "${name}" --ignore-not-found --wait=false
}

delete_apps_matching() {
  local pattern="$1"
  local apps
  apps=$(kubectl -n "${ARGOCD_NAMESPACE}" get applications -o name 2>/dev/null | sed 's#^application.argoproj.io/##' | grep -E "${pattern}" || true)
  if [[ -n "${apps}" ]]; then
    echo "${apps}" | xargs kubectl -n "${ARGOCD_NAMESPACE}" delete application --ignore-not-found --wait=false
  fi
}

delete_workspaces_matching() {
  local pattern="$1"
  local workspaces
  workspaces=$(kubectl get workspaces -o name 2>/dev/null | sed 's#^workspace.tf.upbound.io/##' | grep -E "${pattern}" || true)
  if [[ -n "${workspaces}" ]]; then
    echo "${workspaces}" | xargs kubectl delete workspace --ignore-not-found --wait=false
  fi
}

wait_for_no_workspaces_matching() {
  local pattern="$1"
  local label="$2"
  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))

  echo "Waiting for ${label} Terraform Workspaces to be deleted..."
  while true; do
    local remaining
    remaining=$(kubectl get workspaces -o name 2>/dev/null | sed 's#^workspace.tf.upbound.io/##' | grep -E "${pattern}" || true)

    if [[ -z "${remaining}" ]]; then
      echo "${label} Terraform Workspaces deleted."
      return 0
    fi

    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for ${label} Terraform Workspaces:"
      echo "${remaining}"
      echo "Check Crossplane events before deleting the management cluster."
      return 1
    fi

    echo "${remaining}"
    sleep 15
  done
}

echo "Deleting workload applications first..."
delete_app "2-applications"
delete_appset "hello-world"
delete_appset "blog"
delete_apps_matching '^(hello-world-in-|blog-in-)'

echo "Stopping infrastructure app-of-apps so ApplicationSets are not recreated..."
delete_app "1-infrastructure"

echo "Deleting Cloudflare load balancer Applications..."
delete_appset "provision-load-balancers"
delete_apps_matching '^provision-load-balancer-'
delete_workspaces_matching '^(hello-world|blog)-infrastructure$'
wait_for_no_workspaces_matching '^(hello-world|blog)-infrastructure$' "load balancer"

echo "Deleting managed database Applications..."
delete_appset "blog-db"
delete_apps_matching '^database-for-'
delete_workspaces_matching '.*-database-infrastructure$'
wait_for_no_workspaces_matching '.*-database-infrastructure$' "database"

echo "Deleting workload cluster Applications..."
delete_appset "provision-clusters"
delete_apps_matching '^provision-cluster-'
delete_workspaces_matching '.*-infrastructure$'
wait_for_no_workspaces_matching '.*-infrastructure$' "cluster"

echo "Remaining Terraform Workspaces:"
kubectl get workspaces -A || true

if [[ "${DELETE_K3D_CLUSTER}" == "true" ]]; then
  echo "Deleting local k3d cluster ${K3D_CLUSTER_NAME}..."
  k3d cluster delete "${K3D_CLUSTER_NAME}"
else
  echo "Skipping k3d cluster deletion."
fi

echo "Cleanup completed."
