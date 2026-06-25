# Sealed Secrets Integration

This project uses **Bitnami Sealed Secrets** to:

- safely manage and store sensitive credentials (like cloud provider API tokens) in Git repositories
- while maintaining full GitOps compliance.

## Why Sealed Secrets?

Storing plaintext secrets in Git is a security risk.

Bitnami's Sealed Secrets encrypt secrets using a controller-managed private key.

The encrypted secret (a `SealedSecret`) can be safely stored in Git and will be automatically decrypted into a real Kubernetes `Secret` **only by the controller inside your cluster**.

## Where and How Sealed Secrets Is Used

* **Namespace**: `crossplane-system`
* **Secret Name**: `crossplane-secrets`
* **Usage**: Injects credentials needed by Crossplane Terraform Providers (e.g., `VULTR_TOKEN`, `CIVO_TOKEN`).
* **SealedSecret File Location**:

```
bootstrap/crossplane/0-crossplane-sealed-secrets.yaml
```

* **Applied via**: ArgoCD as part of the `crossplane-terraform-provider` ArgoCD app.

## Script: `seal-mgmt-secrets.sh`

- Automates secure SealedSecret generation using environment tokens.
- Script Actions:

1. Generates a single Secret (crossplane-secrets) containing:

- `CIVO_TOKEN`, `TF_VAR_civo_token`
- `VULTR_TOKEN`, `TF_VAR_vultr_token`

2. Adds annotations and sets type:

- `argocd.argoproj.io/sync-wave: "5"`
- `type: Opaque`

3. Encrypts the secret using `kubeseal` and the **re-used public key:**

- Output: `bootstrap/crossplane/0-crossplane-sealed-secrets.yaml`
- Deletes any temporary plaintext secret files after sealing

### Persistent Encryption Key

To avoid re-sealing secrets every time a new cluster is created:

- We re-use the **same public certificate** (`./sealed-secrets/sealed-secrets-public.pem`) for all management clusters.

- This allows us to **seal secrets once and apply them to any cluster** where the **matching Sealed Secrets controller private key** is configured

##  Key Details

| Property             | Value                                                         |
| -------------------- | ------------------------------------------------------------- |
| **Namespace**        | `crossplane-system`                                           |
| **Secret Name**      | `crossplane-secrets`                                          |
| **Sealed File Path** | `bootstrap/crossplane/0-crossplane-sealed-secrets.yaml`       |
| **Mounted By**       | Crossplane Terraform Provider via `envFrom`                   |
| **Sealed Using**     | `sealed-secrets-public.pem` (checked into `.sealed-secrets/`) |
| **Managed By**       | ArgoCD (part of `crossplane` app sync wave)                   |

## When to Run This Script

- When rotating tokens (e.g.: expired or revoked `Civo/Vultr` tokens)
- When changing values inside the sealed secret.
- If you replace the `public key` in `.sealed-secrets/` (only needed if rotation is manual)

## Troubleshooting

### Problem: SealedSecret cannot be decrypted

ArgoCD may show the `crossplane-secrets` resource as degraded with an error like:

```sh
Failed to unseal: no key could decrypt secret
```

This means the `SealedSecret` was encrypted with a public certificate that does not match the private key currently loaded by the Sealed Secrets controller.

For local rebuilds, the most common cause is that `.sealed-secrets/mgmt/sealed-secrets-key.yaml` was exported with raw Kubernetes metadata and was rejected during k3s startup. If that happens, the controller creates a new key, but `bootstrap/crossplane/0-crossplane-sealed-secrets.yaml` is still encrypted with the old public certificate.

Check which keys are present:

```sh
kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp
```

Check the fingerprint of the local public certificate used by `seal-mgmt-secrets.sh`:

```sh
openssl x509 \
  -in .sealed-secrets/mgmt/sealed-secrets-public.pem \
  -noout -fingerprint -sha256 -dates
```

Check the fingerprint of the active cluster key:

```sh
KEY_NAME=$(kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o jsonpath='{.items[0].metadata.name}')

kubectl -n kube-system get secret "${KEY_NAME}" \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | \
  openssl x509 -noout -fingerprint -sha256 -dates
```

### Fix Steps

1. Make sure the saved management Sealed Secrets key is sanitized:

```sh
yq eval -i 'del(
  .metadata.creationTimestamp,
  .metadata.generateName,
  .metadata.resourceVersion,
  .metadata.uid,
  .metadata.managedFields,
  .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"
)' .sealed-secrets/mgmt/sealed-secrets-key.yaml
```

2. Apply the saved management Sealed Secrets key:

```sh
kubectl apply -f .sealed-secrets/mgmt/sealed-secrets-key.yaml
```

3. Restart the controller so it reloads the saved key:

```sh
kubectl -n kube-system rollout restart deployment/sealed-secrets-controller
kubectl -n kube-system rollout status deployment/sealed-secrets-controller
```

4. Remove any generated key that does not match `.sealed-secrets/mgmt/sealed-secrets-public.pem`.

For example, if the generated key is `sealed-secrets-keyk2csd` and the saved key is `sealed-secrets-keyp26xs`:

```sh
kubectl -n kube-system delete secret sealed-secrets-keyk2csd
```

5. Re-apply or resync the `crossplane-secrets` SealedSecret:

```sh
kubectl apply -f bootstrap/crossplane/0-crossplane-sealed-secrets.yaml
```

Or sync the `crossplane-terraform-provider` Application in ArgoCD.

6. Confirm the decrypted Secret exists:

```sh
kubectl -n crossplane-system get secret crossplane-secrets
```

### Problem: Environment variables not visible inside Terraform Provider Pod

- Check if the secret was properly decrypted:

```sh
kubectl -n crossplane-system get secret crossplane-secrets -o yaml
```

- Check if the values are injected inside the provider pod:

```sh
kubectl get pods -n crossplane-system -l pkg.crossplane.io/provider=provider-terraform

NAME                                                          READY   STATUS    RESTARTS   AGE
crossplane-provider-terraform-xxx-zzz   1/1     Running   0          3h29m
```

```sh
kubectl -n crossplane-system exec -it crossplane-provider-terraform-xxx-zzz -- env | grep VULTR

VULTR_TOKEN=xxxxxxxx
```

If variables like `VULTR_TOKEN` or `TF_VAR_vultr_token` are not present:

### Fix Steps

1. Re-run `seal-mgmt-secrets.sh` with updated environment variables.
2. Re-commit and sync via ArgoCD.
3. Delete the provider pod to force it to reload the updated secret:

```sh
kubectl delete -n crossplane-system crossplane-provider-terraform-xxx-zzz -l pkg.crossplane.io/provider=provider-terraform
```
