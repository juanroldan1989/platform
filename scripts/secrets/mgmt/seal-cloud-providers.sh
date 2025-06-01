#!/bin/bash

set -euo pipefail

# --- Configurable variables ---
NAMESPACE="crossplane-system"
SECRET_NAME="crossplane-secrets"
OUTPUT_FILE="manifests/bootstrap/crossplane/0-crossplane-sealed-secrets.yaml"

# --- Ensure required environment variables are set ---
: "${CIVO_TOKEN:?CIVO_TOKEN is required}"
: "${VULTR_TOKEN:?VULTR_TOKEN is required}"

# --- Create the base secret YAML with annotations and type ---
kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=CIVO_TOKEN="${CIVO_TOKEN}" \
  --from-literal=TF_VAR_civo_token="${CIVO_TOKEN}" \
  --from-literal=VULTR_TOKEN="${VULTR_TOKEN}" \
  --from-literal=TF_VAR_vultr_token="${VULTR_TOKEN}" \
  --dry-run=client -o yaml | \
  yq eval '.metadata.annotations."argocd.argoproj.io/sync-wave" = "5" | .type = "Opaque"' - \
  > "${SECRET_NAME}.yaml"

# --- Seal the secret ---
kubeseal --format=yaml \
  --cert .sealed-secrets/sealed-secrets-public.pem \
  < "${SECRET_NAME}.yaml" > "${OUTPUT_FILE}"

# --- Cleanup ---
rm -f "${SECRET_NAME}.yaml"

echo "✅ SealedSecret created at ${OUTPUT_FILE}"
