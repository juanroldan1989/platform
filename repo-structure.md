# Repository structure

This repository is structured to support

TODO: update this structure with recent updates

**full GitOps-based cluster and platform management** using `ArgoCD` and `Crossplane`.

## `argo/`

Contains all `ArgoCD` applications managed by the bootstrap `ArgoCD` instance.

- `app-of-apps.yaml`: Root `ArgoCD` application that registers all child apps (`tools`, `clusters`, etc.).

- `apps/`: Folder containing categorized `ArgoCD` Applications.

- `clusters/`: Cluster provisioning apps (e.g.: `london.yaml` provisions a `Civo` Kubernetes cluster).

- `tools/`: Platform tool installation apps, such as `Crossplane` and its `Terraform` provider.

## `bootstrap.md`

A step-by-step guide for:

- bootstrapping the local `mgmt-cluster`
- installing `ArgoCD`
- configuring secrets
- initializing `GitOps` management

## `manifests/`

Raw `Kubernetes` manifests used during **initial bootstrapping**, applied automatically by the `bootstrap-k3d.yaml`.

- `bootstrap-k3d.yaml`: Core file mounted into `k3d` to provision `ArgoCD` and **start the GitOps engine.**

- `bootstrap/crossplane/`: Resources needed to bootstrap `Crossplane`.

-- `0-crossplane-secrets.yaml`: Secret holding your `CIVO` API token.

-- `1-rbac-argocd-crossplane.yaml`: Grants `ArgoCD` permission to manage `Crossplane Workspaces`.

-- `2-provider-terraform.yaml`: Installs the `Crossplane Terraform` provider.

-- `3-provider-terraform-config.yaml`: Configures the `Terraform` provider runtime.

## `registry/`

GitOps-friendly registry of cluster provisioning resources.

- `clusters/london/`: Defines everything needed to provision a `london` Kubernetes cluster via `Crossplane`.

-- `provider-config.yaml`: Configures **backend and credentials** for `Terraform`.

-- `workspace.yaml`: Triggers the `Terraform` module that **provisions the cluster.**

-- `wait.yaml`: Waits for the workspace to complete before continuing.

## `terraform/`

Reusable `Terraform` modules used by `Crossplane Workspaces`.

- `modules/cluster/`: The `Terraform` logic for **provisioning a Civo cluster.**

-- `main.tf`: Declares the network, firewall, Kubernetes cluster and ArgoCD access setup.

-- `variables.tf`: Defines expected input variables like `cluster_name`, `node_count`, etc.
