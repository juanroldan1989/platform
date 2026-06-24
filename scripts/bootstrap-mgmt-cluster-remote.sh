#!/bin/bash

set -euo pipefail

# Customize these variables
AWS_PROFILE="default"
CLUSTER_NAME="mgmt"
NODE_COUNT=1
NODE_SIZE="g4s.kube.large"
K8S_VERSION="1.35.0-k3s1"
REGION="LON1"

echo "🌍 Detecting your public IP..."
MY_PUBLIC_IP=$(curl -s https://api.ipify.org)
CIDR="$MY_PUBLIC_IP/32"
echo "📍 Your current IP is: ${CIDR}"

FIREWALL_NAME="${CLUSTER_NAME}-fw"

echo "🛡️ Creating restricted firewall: $FIREWALL_NAME"

civo firewall create "$FIREWALL_NAME" --region "$REGION"

# Allow HTTPS and HTTP from everywhere
civo firewall rule create "$FIREWALL_NAME" --startport 80 --endport 80 --protocol tcp --cidr "0.0.0.0/0" --direction ingress --region "$REGION"
civo firewall rule create "$FIREWALL_NAME" --startport 443 --endport 443 --protocol tcp --cidr "0.0.0.0/0" --direction ingress --region "$REGION"

# Allow Kubernetes API (6443) only from your current IP
civo firewall rule create "$FIREWALL_NAME" --startport 6443 --endport 6443 --protocol tcp --cidr "$CIDR" --direction ingress --region "$REGION"

# Optional: Allow SSH from your current IP if needed
# civo firewall rule create "$FIREWALL_NAME" --startport 22 --endport 22 --protocol tcp --cidr "$CIDR" --direction ingress --region "$REGION"

# Allow all egress
civo firewall rule create "$FIREWALL_NAME" --startport 1 --endport 65535 --protocol tcp --cidr "0.0.0.0/0" --direction egress --region "$REGION"

echo "🧹 Cleaning up insecure default ingress rules added by Civo..."
FIREWALL_ID=$(civo firewall ls --region "$REGION" -o json | jq -r ".[] | select(.name == \"$FIREWALL_NAME\") | .id")

if [[ -z "$FIREWALL_ID" ]]; then
  echo "❌ Could not find firewall ID for $FIREWALL_NAME"
  exit 1
fi

civo firewall rule ls "$FIREWALL_ID" --region "$REGION" -o json > tmp_rules.json

UNWANTED_RULE_IDS=$(jq -r '.[] | select(
  .direction == "ingress" and (
    (.protocol == "tcp" and (.start_port | tonumber) == 1 and (.end_port | tonumber) == 65535) or
    (.protocol == "udp" and (.start_port | tonumber) == 1 and (.end_port | tonumber) == 65535) or
    (.protocol == "icmp")
  )
) | .id' tmp_rules.json)

for rule_id in $UNWANTED_RULE_IDS; do
  echo "🚫 Deleting insecure rule ID: $rule_id"
  civo firewall rule remove $FIREWALL_ID $rule_id --region "$REGION" --yes
done

rm tmp_rules.json
echo "✅ Finished removing default insecure firewall rules."

echo "✅ Firewall rules cleaned up. Cluster access is now restricted to intended sources."

echo "🚀 Creating Civo Kubernetes cluster: $CLUSTER_NAME..."
civo kubernetes create "$CLUSTER_NAME" \
  --nodes "$NODE_COUNT" \
  --size "$NODE_SIZE" \
  --version "$K8S_VERSION" \
  --cluster-type k3s \
  --existing-firewall "$FIREWALL_NAME" \
  --region "$REGION" \
  --wait \
  --save \
  --switch

echo "✅ Cluster created and kubeconfig updated locally"

echo "🔗 Setting up kubeconfig for the new cluster..."
unset KUBECONFIG
kubectl config use-context mgmt

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

echo "🔄 Provisioning "management" cluster with essentials ..."
kubectl apply -f bootstrap/mgmt-cluster.yaml

echo "✅ Bootstrap completed. ArgoCD should self-manage itself shortly."
