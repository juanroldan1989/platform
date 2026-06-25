#!/bin/bash

set -euo pipefail

OUTPUT_DIR=".sealed-secrets/mgmt"
CONTROLLER_NAME="sealed-secrets-controller"
CONTROLLER_NAMESPACE="kube-system"
KEY_LABEL="sealedsecrets.bitnami.com/sealed-secrets-key=active"

mkdir -p "${OUTPUT_DIR}"

echo "Waiting for Sealed Secrets controller..."
kubectl -n "${CONTROLLER_NAMESPACE}" rollout status \
  "deployment/${CONTROLLER_NAME}" \
  --timeout=120s

echo "Exporting Sealed Secrets public certificate..."
kubeseal --fetch-cert \
  --controller-name "${CONTROLLER_NAME}" \
  --controller-namespace "${CONTROLLER_NAMESPACE}" \
  > "${OUTPUT_DIR}/sealed-secrets-public.pem"

KEY_NAME=$(kubectl -n "${CONTROLLER_NAMESPACE}" get secret \
  -l "${KEY_LABEL}" \
  -o jsonpath='{.items[0].metadata.name}')

if [[ -z "${KEY_NAME}" ]]; then
  echo "Could not find an active Sealed Secrets key in ${CONTROLLER_NAMESPACE}."
  exit 1
fi

echo "Exporting reusable Sealed Secrets private key manifest..."
kubectl -n "${CONTROLLER_NAMESPACE}" get secret "${KEY_NAME}" -o yaml | \
  yq eval 'del(
    .metadata.creationTimestamp,
    .metadata.generateName,
    .metadata.resourceVersion,
    .metadata.uid,
    .metadata.managedFields,
    .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"
  )' - \
  > "${OUTPUT_DIR}/sealed-secrets-key.yaml"

echo "Exported ${OUTPUT_DIR}/sealed-secrets-public.pem"
echo "Exported sanitized ${OUTPUT_DIR}/sealed-secrets-key.yaml"
