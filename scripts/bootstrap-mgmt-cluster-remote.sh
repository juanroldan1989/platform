#!/bin/bash

# Customize these variables
CLUSTER_NAME="mgmt-cluster"
NODE_COUNT=1
NODE_SIZE="g4s.kube.large"
REGION="LON1"

echo "🌐 Creating Civo Kubernetes cluster: $CLUSTER_NAME..."

civo kubernetes create "$CLUSTER_NAME" \
  --nodes "$NODE_COUNT" \
  --size "$NODE_SIZE" \
  --cluster-type k3s \
  --create-firewall \
  --firewall-rules "6443" \
  --region "$REGION" \
  --wait \
  --save \
  --merge \
  --switch

echo "✅ Cluster created and kubeconfig updated locally"

echo "🔗 Setting up kubeconfig for the new cluster..."
unset KUBECONFIG
kubectl config use-context mgmt-cluster

echo "🔐 Injecting Sealed Secrets public key..."
kubectl apply -f .sealed-secrets/mgmt/sealed-secrets-key.yaml -n kube-system

echo "🔄 Provisioning mgmt-cluster with essentials ..."
kubectl apply -f manifests/bootstrap/mgmt-cluster.yaml

echo "✅ Bootstrap completed. ArgoCD should self-manage itself shortly."
