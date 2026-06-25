#!/bin/bash

set -euo pipefail

# Customize these variables
AWS_PROFILE="default"
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

echo "✅ Bootstrap completed. ArgoCD should self-manage itself shortly."
