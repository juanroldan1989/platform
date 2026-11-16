# Repository Structure

This repository contains Argo CD Applications and ApplicationSets, Helm charts,
Terraform modules, bootstrap scripts and documentation for a GitOps-based
Kubernetes platform. Configuration is separated into platform services,
infrastructure provisioning and application workloads.

## Overview

```text
platform/
├── README.md
├── .gitignore
├── argo/
│   ├── app-of-apps.yaml
│   ├── 0-platform/
│   ├── 1-infrastructure/
│   └── 2-applications/
├── bootstrap/
│   ├── mgmt-cluster.yaml
│   └── crossplane/
├── registry/
│   ├── apps/
│   ├── clusters/
│   │   ├── mgmt/
│   │   ├── overlays/
│   │   └── workload/
│   ├── databases/
│   └── load_balancers/
├── scripts/
├── terraform/
│   └── modules/
└── zdocs/
    ├── ROADMAP.md
    ├── repo-structure.md
    ├── architecture/
    ├── bootstrap/
    ├── networking/
    ├── operations/
    ├── proposals/
    └── providers/
```

## `argo/`

[Argo CD definitions](../argo/) describe which sources are reconciled and where
their resources are deployed.

- `app-of-apps.yaml`: Commented-out definition of an overarching root Application
  selecting the three domain roots. It currently contains no active manifest.
- `0-platform/app-of-apps.yaml`: Domain root for platform services. Its directory
  source recursively reads `argo/0-platform/`.
- `1-infrastructure/app-of-apps.yaml`: Domain root for infrastructure provisioning.
- `2-applications/app-of-apps.yaml`: Domain root for application workloads.

### `0-platform/`

- `argocd-support/`: Applications for the default project, server ingress and
  management-cluster registration Secret.
- `cert-manager/`: Certificate-manager installation and supporting resources.
- `crossplane/`: Crossplane installation and an Application referencing its
  bootstrap/provider resources.
- `eso/`: External Secrets Operator installation and management-cluster support.
- `observability/`: ApplicationSets for observability bootstrap, metrics CRDs,
  metrics/Grafana, OpenTelemetry Collector, Jaeger, Beyla and GPU metrics.
- `external-dns-config.yaml`, `ingress-nginx-config.yaml`, `sealed-secrets.yaml`:
  ApplicationSets for DNS, ingress and sealed-secret services.
- `gpu-operator.yaml`: NVIDIA GPU Operator ApplicationSet targeting workload
  clusters labelled for GPU use.

### `1-infrastructure/`

- `clusters/provision.yaml`: ApplicationSet discovering cluster overlays and
  rendering the workload provisioning chart.
- `clusters/config.yaml`: ApplicationSet referencing workload configuration.
- `clusters/secrets/`: Applications/ApplicationSets for management and workload
  secret resources.
- `databases/blog.yaml`: ApplicationSet for database overlay provisioning.
- `load_balancers/provision.yaml`: ApplicationSet for load-balancer overlays.

### `2-applications/`

`hello-world.yaml`, `blog.yaml` and `ai-chat.yaml` define ApplicationSets that
deploy their charts to selected workload clusters. The AI application additionally
requires the GPU cluster label.

## `bootstrap/`

[Bootstrap resources](../bootstrap/) initialize Argo CD and configure the
Crossplane Terraform integration.

- `mgmt-cluster.yaml`: Namespace, service account, RBAC and Jobs to install Argo CD
  and apply the `0-platform` domain root. It does not currently apply the other
  two domain roots.
- `crossplane/0-crossplane-sealed-secrets.yaml`: Sealed provider credentials.
- `crossplane/1-rbac-argocd-crossplane.yaml`: RBAC for reading Terraform Workspaces.
- `crossplane/2-provider-terraform.yaml`: Crossplane Terraform provider package.
- `crossplane/3-provider-terraform-config.yaml`: Provider controller configuration.
- `crossplane/4-toolbox.yaml`: Toolbox resources for administrative access.

## `registry/`

[Registry sources](../registry/) contain the charts, values and support manifests
referenced by the Argo CD definitions.

### `apps/`

- `hello-world/`: Helm chart for the HTTP echo demonstration workload.
- `blog/`: Helm chart for the current Wiki.js/PostgreSQL-backed workload, retaining
  the historical `blog` name.
- `ai-chat/`: Helm chart and values for Ollama, Open WebUI, persistent storage and
  model provisioning, plus a README and Ollama/vLLM comparison notes.

### `clusters/`

- `mgmt/`: Management-cluster app manifests, External DNS and ingress values,
  ESO values/support configuration and sealed Cloudflare-token manifests.
- `overlays/`: Cluster-specific values under `in-cluster/`, `london/`,
  `frankfurt/`, `newyork/` and `nuremberg/`. An overlay's presence alone does not
  establish that its provisioning is enabled or verified.
- `workload/provision/`: Parent Helm chart with local `civo/`, `vultr/` and
  `hetzner/` dependencies. Each provider chart contains ProviderConfig, Workspace
  and wait-job templates. Cluster Workspaces reference the external `infra-modules`
  repository.
- `workload/config/`: Values for `blog-db`, ESO, External DNS, ingress, GPU Operator
  and observability. The observability directory also contains a bootstrap chart,
  component-specific values and its own README.
- `workload/support/`: Certificate-manager support chart and ESO RBAC/store
  manifests.
- `workload/secrets/`: ExternalSecret manifests for database credentials and
  Cloudflare tokens.

### `databases/`

- `overlays/blog/values.yaml`: Managed database configuration.
- `provision/`: Helm chart with ProviderConfig and Workspace templates, readiness
  Jobs, a database-catalog creation Job and an ESO PushSecret template.

### `load_balancers/`

- `overlays/blog/values.yaml`: Cloudflare load-balancer configuration for the blog.
- `overlays/hello-world/values.yaml`: Existing overlay with its values commented out.
- `provision/`: Helm chart with ProviderConfig, Workspace and wait-job templates.

## `scripts/`

[Helper scripts](../scripts/) support bootstrap, credentials and teardown.

- `bootstrap-mgmt-cluster-local.sh`: Creates the management-cluster AWS credentials
  Secret from a local AWS profile; local cluster creation is documented separately.
- `bootstrap-mgmt-cluster-remote.sh`: Creates a Civo management cluster/firewall,
  installs existing secret-key material and credentials, and applies bootstrap.
- `export-sealed-secrets-key.sh`: Exports the controller key and public certificate
  for reuse when recreating the management cluster.
- `seal-mgmt-secrets.sh`: Seals provider credentials for bootstrap.
- `cleanup-mgmt-cluster-local.sh`: Performs staged teardown of managed resources
  and optionally deletes the local k3d management cluster.

Local Sealed Secrets key material is kept under `.sealed-secrets/`, which is
excluded by `.gitignore`.

## `terraform/modules/`

[Terraform modules](../terraform/modules/) implemented in this repository:

- `civo_database/`: Managed database provisioning, connection outputs and a
  management-cluster credentials Secret.
- `cloudflare_lb/`: Cloudflare load balancer, London/Frankfurt pools and monitor.

Cluster provisioning modules are referenced remotely from
`juanroldan1989/infra-modules`; they are not stored in this directory.

## `zdocs/`

Only [ROADMAP.md](ROADMAP.md) and this [repository structure guide](repo-structure.md)
remain at the documentation root.

| Folder | Documents |
| --- | --- |
| [architecture/](architecture/) | [Platform paradigms](architecture/2-paradigms.md), [scaling options](architecture/a-current-scaling-problem-and-scaling-options.md), [bundle refactor](architecture/a-next-steps-refactor-with-bundle.md) |
| [bootstrap/](bootstrap/) | [Local management cluster](bootstrap/bootstrap-mgmt-cluster-local.md), [remote management cluster](bootstrap/bootstrap-mgmt-cluster-remote.md) |
| [networking/](networking/) | [Cloudflare load balancing](networking/cloudflare-lb.md), [DNS and HTTPS](networking/dns.md) |
| [operations/](operations/) | [Data](operations/data.md), [secrets](operations/secrets.md), [security](operations/security.md), [observability](operations/observability.md), [blog failover](operations/failover-blog.md), [Hello World failover](operations/failover-hello-world.md) |
| [proposals/](proposals/) | [Combined next steps](proposals/a-next-steps.md), [regional databases](proposals/a-next-steps-database.md), [central secret backend](proposals/a-next-steps-central-secret-backend.md), [canary deployments](proposals/a-next-steps-canary-deployments.md) |
| [providers/](providers/) | [Civo](providers/civo.md), [Vultr](providers/vultr.md), [Civo GitOps provisioning recording](providers/civo-workload-cluster-provisioned-via-gitops.md) |

Architecture notes, proposals and historical walkthroughs describe different
revisions or intended changes. Use the roadmap to distinguish planned work from
implemented and validated capabilities.
