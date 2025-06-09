#!/bin/bash

# Customize these variables
AWS_PROFILE="default"
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
  --switch

echo "✅ Cluster created and kubeconfig updated locally"

echo "🔗 Setting up kubeconfig for the new cluster..."
unset KUBECONFIG
kubectl config use-context mgmt-cluster

echo "🔐 Injecting Sealed Secrets public key..."
kubectl apply -f .sealed-secrets/mgmt/sealed-secrets-key.yaml -n kube-system

# TODO: seal AWS credentials (similar as cloud providers) and generate aws-creds decrypting them afterwards
echo "🔍 Checking AWS profile: ${AWS_PROFILE}"
ACCESS_KEY=$(aws configure get aws_access_key_id --profile "${AWS_PROFILE}")
SECRET_KEY=$(aws configure get aws_secret_access_key --profile "${AWS_PROFILE}")

if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
  echo "❌ AWS credentials not found in profile '${AWS_PROFILE}'"
  exit 1
fi
echo "✅ AWS credentials loaded from profile '${AWS_PROFILE}'"

echo "🔐 Creating AWS secret for ESO (External Secrets Operator) - MGMT Cluster internal use"
kubectl create ns external-secrets || true
kubectl create secret generic aws-creds \
  --namespace external-secrets \
  --from-literal=access-key="$ACCESS_KEY" \
  --from-literal=secret-access-key="$SECRET_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔄 Provisioning mgmt-cluster with essentials ..."
kubectl apply -f manifests/bootstrap/mgmt-cluster.yaml

echo "✅ Bootstrap completed. ArgoCD should self-manage itself shortly."
