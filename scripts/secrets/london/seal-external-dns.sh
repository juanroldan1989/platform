#!/bin/bash

set -euo pipefail

# --- Configurable variables ---
NAMESPACE="external-dns"
SECRET_NAME="cloudflare-api-token"
OUTPUT_FILE="manifests/bootstrap/crossplane/0-sealed-external-dns-secrets.yaml"

# --- Ensure required environment variables are set ---
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"

# --- Create the base secret YAML with annotations and type ---
kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}" \
  --dry-run=client -o yaml | \
  yq eval '.metadata.annotations."argocd.argoproj.io/sync-wave" = "5" | .type = "Opaque"' - \
  > "${SECRET_NAME}.yaml"

# --- Seal the secret ---
kubeseal --format=yaml \
  --cert .sealed-secrets/london/sealed-secrets-public.pem \
  < "${SECRET_NAME}.yaml" > "${OUTPUT_FILE}"

# --- Cleanup ---
rm -f "${SECRET_NAME}.yaml"

echo "✅ SealedSecret created at ${OUTPUT_FILE}"
