# Repository Structure

This repository supports **full GitOps-based multi-cloud Kubernetes cluster provisioning** using

- **ArgoCD**
- **Crossplane**
- **Terraform**

It is designed to be modular, extensible, and cloud-agnostic.

## `argo/`

ArgoCD Applications and tool registration.

- `app-of-apps.yaml`: Root ArgoCD `Application` that registers all other apps (tools, clusters, load balancers).
- `apps/`: Standalone apps like `hello-world`.
- `clusters/`: Cluster provisioning-related ArgoCD apps.
  - `provision.yaml`: ArgoCD `ApplicationSet` that provisions clusters using Helm and Crossplane.
  - `config.yaml`: Common ArgoCD `ApplicationSet` for per-cluster configuration (addons).
  - `secrets/`: SealedSecrets for in-cluster and workload use.
- `load_balancers/`: ArgoCD `ApplicationSet` that provisions global Cloudflare Load Balancers.
- `tools/`: ArgoCD apps for platform-wide tools:
  - `argocd-support/`: ArgoCD UI ingress and default project definition.
  - `cert-manager/`, `eso/`, `crossplane/`: Helm charts for critical control-plane tools.
  - `external-dns-config.yaml`, `ingress-nginx-config.yaml`, `sealed-secrets.yaml`: Configuration for common ingress/DNS/secrets tools.

## `bootstrap/`

Bootstrapping logic for initializing the management cluster.

- `mgmt-cluster.yaml`: First app applied to install ArgoCD and launch GitOps.
- `crossplane/`: Bootstrap sequence for Crossplane and Terraform runtime.
  - `0-crossplane-sealed-secrets.yaml`: SealedSecrets required for provider tokens.
  - `1-rbac-argocd-crossplane.yaml`: ArgoCD RBAC permissions to manage Crossplane.
  - `2-provider-terraform.yaml`: Installs the Crossplane Terraform provider.
  - `3-provider-terraform-config.yaml`: Terraform provider configuration.
  - `4-toolbox.yaml`: Utility jobs/resources.

## `scripts/`

Helper shell scripts used during cluster bootstrapping or secret management.

- `bootstrap-mgmt-cluster-remote.sh`: Provisions a remote Civo cluster and bootstraps GitOps.
- `seal-mgmt-secrets.sh`: Seals secret tokens for bootstrap use.

## `registry/`

Declarative cluster and addon configuration for all environments.

### `clusters/`

- `in-cluster/`: Configuration and secrets for the management cluster itself.
- `overlays/`: Per-cluster overlays (e.g. `london`, `frankfurt`, `newyork`) containing `values.yaml` used by ApplicationSets to determine cluster-specific values.
- `workload/`: Helm charts to provision and configure clusters.

#### `workload/provision/`

- `Chart.yaml`: Main chart with subchart dependencies for supported cloud providers (e.g., `civo`, `vultr`).
- `values.yaml`: Shared/default values for provisioning.
- `civo/`, `vultr/`: Subcharts with provider-specific templates:
  - `provider-config.yaml`: Crossplane ProviderConfig definition (Terraform + credentials).
  - `workspace.yaml`: Crossplane Workspace definition pointing to a Terraform module.
  - `wait.yaml`: Optional resource wait logic.

#### `workload/config/`, `workload/apps/`, `workload/support/`, `workload/secrets/`

- Configuration for addons (`cert-manager`, `external-dns`, `ingress-nginx`, `eso`)
- Application deployment charts (`hello-world`)
- Cluster-wide support files (`cluster-issuer`, RBAC, sealed secrets, etc.)

## `registry/load_balancers/`

Load balancer provisioning via Terraform and GitOps.

- `overlays/hello-world/values.yaml`: Defines backend endpoints for Cloudflare LB.
- `provision/`: Helm chart that provisions a `Workspace` to deploy the Cloudflare LB using Terraform.

## `terraform/`

Reusable Terraform modules used by Crossplane Workspaces.

- `modules/civo_cluster/`: Module to provision `Civo` Kubernetes clusters.
- `modules/vultr_cluster/`: Module to provision `Vultr` Kubernetes clusters.
- `modules/cloudflare_lb/`: Module to provision a `Cloudflare Load Balancer`.

Each module includes:

- `main.tf`: Terraform resources
- `variables.tf`: Input variables required by the module

## Docs & Guides

- `README.md`: Project overview and getting started
- `repo-structure.md`: This file
- `bootstrap-mgmt-cluster-local.md`: Step-by-step for `local` development
- `bootstrap-mgmt-cluster-remote.md`: Step-by-step for `remote` MGMT production cluster
- `civo.md`, `vultr.md`: Cloud-specific setup notes
- `cloudflare-lb.md`, `dns.md`, `secrets.md`: Functional documentation for external DNS, LB, and secrets management
