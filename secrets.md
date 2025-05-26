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
* **Usage**: Injects credentials needed by Crossplane Terraform Providers (e.g., `VULTR_TOKEN`, `TF_VAR_vultr_token`).
* **SealedSecret File Location**:

```
manifests/bootstrap/crossplane/0-crossplane-sealed-secrets.yaml
```

* **Applied via**: ArgoCD as part of the `crossplane` app.

## Script: `seal-secret.sh`

This script automates the process of creating a `SealedSecret` for storing sensitive environment variables:

### Steps Performed by the Script

1. **Extract Public Key from Sealed Secrets Controller**:

* Uses `kubectl` to get the public key from the controller running in the cluster.

2. **Create Temporary Plain Secret**:

* Uses environment variable `VULTR_TOKEN` to create a temporary `Secret` manifest with sensitive values.

3. **Seal the Secret**:

* Uses `kubeseal` CLI to encrypt the secret using the public key.
* Output is written to:

```
manifests/bootstrap/crossplane/0-crossplane-sealed-secrets.yaml
```

4. **Clean up**:

* Deletes temporary plaintext files.

### When to Run This Script

* Every time you:

- **Create a new cluster** where Sealed Secrets is deployed (new key pair generated)
- **Update tokens** (e.g.: new `VULTR_TOKEN`)

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
crossplane-provider-terraform-e816b322200e-674cb76566-v4pwb   1/1     Running   0          3h29m
```

```sh
kubectl -n crossplane-system exec -it crossplane-provider-terraform-e816b322200e-674cb76566-v4pwb -- env | grep VULTR

VULTR_TOKEN=xxxxxxxx
```

If variables like `VULTR_TOKEN` or `TF_VAR_vultr_token` are not present:

### Fix Steps

1. Re-run `seal-secret.sh` with updated environment variables.
2. Re-commit and sync via ArgoCD.
3. Restart the provider pod to force it to reload the updated secret:

```sh
kubectl -n crossplane-system delete pod -l pkg.crossplane.io/provider=provider-terraform
```

4. Also check

## Summary

* Sealed Secrets ensures secure, GitOps-compliant secret management.
* The sealed secret is committed to Git and synced via ArgoCD.
* Run `seal-secret.sh` whenever tokens or clusters change.
* Restart the provider pods if secrets don’t take effect.

Stay secure, stay GitOps-aligned.
