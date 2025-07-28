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

## Script: `seal-secrets.sh`

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

1. Re-run `seal-secret.sh` with updated `VULTR_TOKEN` environment variable/s.
2. Re-commit and sync via ArgoCD.
3. Delete the provider pod to force it to reload the updated secret:

```sh
kubectl delete -n crossplane-system crossplane-provider-terraform-xxx-zzz -l pkg.crossplane.io/provider=provider-terraform
```
