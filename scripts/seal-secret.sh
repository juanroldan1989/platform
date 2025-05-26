#!/bin/bash

set -euo pipefail

NAMESPACE="crossplane-system"
SECRET_NAME="crossplane-secrets"
OUTPUT_FILE="manifests/bootstrap/crossplane/0-crossplane-sealed-secrets.yaml"

# 1. Extract the Sealed Secrets controller public key
echo "[INFO] Extracting Sealed Secrets controller public key from cluster..."
kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o jsonpath="{.items[0].data['tls\.crt']}" | base64 -d > /tmp/controller-public.pem

# 2. Define your secret as plaintext YAML
echo "[INFO] Creating temporary plaintext secret manifest..."
cat <<EOF > /tmp/tmp-plain-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  VULTR_TOKEN: VULTR_TOKEN
  TF_VAR_vultr_token: VULTR_TOKEN
EOF

# 3. Seal the secret using the extracted public key
echo "[INFO] Sealing the secret..."
kubeseal --format=yaml --cert=/tmp/controller-public.pem \
  < /tmp/tmp-plain-secret.yaml > "${OUTPUT_FILE}"

echo "[SUCCESS] SealedSecret written to ${OUTPUT_FILE}"

# 4. Cleanup
rm /tmp/tmp-plain-secret.yaml /tmp/controller-public.pem
