# Introduction

The [platform](https://github.com/juanroldan1989/platform) repository is built to manage Kubernetes-based application environments using `GitOps` principles.

It provides foundational infrastructure and automation to support deploying applications across `workload` clusters.

Each cluster is provisioned across `regions` and `cloud providers` (CIVO, Vultr), achieving high availability and reliability.

## Goals

This repository's mission is to **enable a streamlined, scalable and self-service platform** where:

1. Application teams focus solely on **developing their apps in separate repositories** (e.g.: [applications](https://github.com/juanroldan1989/applications) repo).

2. Platform engineers use this [platform](https://github.com/juanroldan1989/platform) repository to follow `GitOps` practices and define:

* `MGMT` (management) Cluster
* `Workload` Clusters
* User Applications and their target `workload` clusters (across regions and cloud providers).
* A GitOps control plane: `ArgoCD` server within `MGMT` cluster, accessible via NGINX Ingress through SSL.

3. GitOps principles ensures **transparency**, **traceability** and **automation** across all environments (e.g.: `DEV`, `TEST`, `PROD`) and regions (e.g.: `newyork`, `london`, `barcelona`, `dublin`).

## `platform` repo – setup (local / cloud)

Platform engineers can use this repository to:

### 1. Provision `Management` Cluster

* Provisions a `mgmt-cluster` automatically using `CIVO` or a local setup (e.g.: `kind`)
* Configures core tools: ArgoCD, Sealed Secrets, Cert-Manager, External-DNS and NGINX Ingress.
* Removes the need for manual scripts wherever possible.

### 2. Provision `Workload` Clusters

* Applies `GitOps` principles to provision `workload` clusters such as `newyork`, `london`, `barcelona` and `dublin`.
* **Registers each workload** cluster in `ArgoCD` server via `GitOps` automation.
* Configures each cluster with required addons: ESO, NGINX Ingress, Cert-Manager, External-DNS, etc.
* Follows the same GitOps flow to minimize manual interaction.

### 3. Provision `Load Balancers`

* Automated provisioning of cloud load balancers using Terraform/Crossplane
* Cloudflare Load Balancer configuration for global traffic distribution
* Health checks and failover configuration for high availability
* GitOps-managed load balancer policies and SSL termination

### 4. Provision `Databases`

* Managed database provisioning using CIVO DBaaS via Terraform modules
* Multi-cluster database credential distribution using AWS Secrets Manager
* External Secrets Operator (ESO) for secure cross-cluster secret synchronization
* Automated database backup and scaling policies

### 5. Deploy `Applications`

* Applications are defined declaratively in `registry/clusters/{{cluster}}/apps`.
* A single **ArgoCD ApplicationSet** resource per application keeps apps in sync across clusters and cloud providers.
* Ingress and `TLS` settings are managed inside each cluster's registry folder: `registry/clusters/{{cluster}}/external-dns`

## Platform Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                GitOps Control Plane                                 │
│                            ┌─────────────────────────────┐                          │
│                            │     Management Cluster      │                          │
│                            │      (in-cluster)           │                          │
│                            │                             │                          │
│                            │  ┌─────────┐ ┌────────-─┐   │                          │
│                            │  │ ArgoCD  │ │Crossplane│   │                          │
│                            │  │         │ │          │   │                          │
│                            │  └─────────┘ └────────-─┘   │                          │
│                            │                             │                          │
│                            │  ┌─────────┐ ┌─────────┐    │                          │
│                            │  │   ESO   │ │Terraform│    │                          │
│                            │  │         │ │         │    │                          │
│                            │  └─────────┘ └─────────┘    │                          │
│                            └─────────────────────────────┘                          │
│                                         │                                           │
│                                         │ GitOps Sync                               │
│                                         │                                           │
│                    ┌────────────────────┼────────────────────┐                      │
│                    │                    │                    │                      │
│                    ▼                    ▼                    ▼                      │
│            ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                │
│            │   London    │      │  Frankfurt  │      │  New York   │                │
│            │   Cluster   │      │   Cluster   │      │   Cluster   │                │
│            │             │      │             │      │             │                │
│            │ ┌─────────┐ │      │ ┌─────────┐ │      │ ┌─────────┐ │                │
│            │ │   App   │ │      │ │   App   │ │      │ │   App   │ │                │
│            │ │ (Blog)  │ │      │ │ (Blog)  │ │      │ │ (Blog)  │ │                │
│            │ └─────────┘ │      │ └─────────┘ │      │ └─────────┘ │                │
│            │             │      │             │      │             │                │
│            │ ┌─────────┐ │      │ ┌─────────┐ │      │ ┌─────────┐ │                │
│            │ │   ESO   │ │      │ │   ESO   │ │      │ │   ESO   │ │                │
│            │ │         │ │      │ │         │ │      │ │         │ │                │
│            │ └─────────┘ │      │ └─────────┘ │      │ └─────────┘ │                │
│            └─────────────┘      └─────────────┘      └─────────────┘                │
│                    │                    │                    │                      │
│                    └────────────────────┼────────────────────┘                      │
│                                         │                                           │
│                                         ▼                                           │
│                              ┌─────────────────────┐                                │
│                              │   Shared Resources  │                                │
│                              │                     │                                │
│                              │  ┌─────────────┐    │                                │
│                              │  │    CIVO     │    │                                │
│                              │  │   Database  │    │                                │
│                              │  └─────────────┘    │                                │
│                              │                     │                                │
│                              │  ┌─────────────┐    │                                │
│                              │  │     AWS     │    │                                │
│                              │  │   Secrets   │    │                                │
│                              │  │   Manager   │    │                                │
│                              │  └─────────────┘    │                                │
│                              │                     │                                │
│                              │  ┌─────────────┐    │                                │
│                              │  │ Cloudflare  │    │                                │
│                              │  │Load Balancer│    │                                │
│                              │  └─────────────┘    │                                │
│                              └─────────────────────┘                                │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

This architecture demonstrates the complete GitOps-based multi-cluster platform with:
- **Centralized Control**: Management cluster orchestrates all operations
- **Distributed Applications**: Workload clusters across multiple regions
- **Shared Resources**: Managed databases and load balancers
- **Secure Communication**: ESO-based secret distribution

## Applications with External Access

### How do we install, validate and define Ingress resources GitOps-style?

* Ingress resources are declared within each cluster's registry folder: `registry/clusters/{{cluster}}/ingress-nginx`
* NGINX Ingress Controller is installed via ArgoCD into each workload cluster.
* Ingress is automatically routed via `LoadBalancer` and DNS Manager.

### How is cert-manager handled for each app?

* A `ClusterIssuer` is defined using `Let’s Encrypt` with `DNS-01` challenge via `Cloudflare`.
* `cert-manager` auto-issues certificates for any ingress using the shared wildcard TLS secret.
* Secrets are managed with **External Secrets Operator** and `GitOps`.

### How DNS records are managed?

* DNS records are stored within `Cloudflare`.

* `external-dns` allows us to:

- synchronize **exposed Kubernetes Services and Ingresses** with **DNS providers.**
- monitor Ingresses and creates `A/TXT` records in `Cloudflare`.

* It authenticates using a shared `Cloudflare API token`, managed with `ESO` and `GitOps`.
* Each cluster (e.g., `london`, `frankfurt`, `newyork`) can expose a unique subdomain securely.
* For example, `app.london.automatalife.com` is a real endpoint exposed securely via HTTPS.

### Quick Local Testing Without DNS Propagation

To test while waiting for DNS propagation:

```bash
sudo nano /etc/hosts
```

Add:

```text
74.220.20.97   app.london.automatalife.com
```

Then open in your browser or use:

```bash
curl -v https://app.london.automatalife.com
```

Remember to remove it afterward to prevent stale DNS routing.

## Security & Compliance

### Secret Management
- **Sealed Secrets**: Encrypted secrets stored in Git repository
- **External Secrets Operator**: Runtime secret injection from AWS Secrets Manager
- **RBAC**: Role-based access control for ArgoCD and cluster access
- **TLS Everywhere**: All traffic encrypted with Let's Encrypt certificates

### Network Security
- **Private Networking**: Clusters communicate via private networks where possible
- **Firewall Rules**: Managed database access restricted to cluster networks
- **DNS Security**: Cloudflare protection against DDoS and DNS attacks
- **Ingress Security**: NGINX Ingress with rate limiting and security headers

### Credential Rotation
- **Automated Rotation**: AWS Secrets Manager handles credential lifecycle
- **GitOps Sync**: Changes propagated automatically to all clusters
- **Audit Trail**: All changes tracked through Git history and ArgoCD events

## Failover & High Availability

### Application Failover
- **Stateless Applications**: Automatic failover between regions (e.g., Hello World app)
- **Stateful Applications**: Database-backed apps with shared data layer (e.g., Blog app)

### Infrastructure Failover
- **Multi-Region Deployment**: Applications deployed across multiple CIVO regions
- **Load Balancer Failover**: Cloudflare health checks and automatic traffic routing
- **Database High Availability**: CIVO managed database with built-in failover

### Detailed Scenarios
- `Hello World` app (stateless): All details [here](/failover-hello-world.md)
- `Blog` app (stateful): All details [here](/failover-blog.md)

## Monitoring & Observability

### GitOps Monitoring
- **ArgoCD Dashboard**: Real-time view of all applications and their sync status
- **Application Health**: Automated health checks for all deployed applications
- **Sync Status**: Visual indicators for drift detection and remediation

### Infrastructure Monitoring
- **Cluster Health**: Kubernetes cluster metrics and node status
- **Resource Usage**: CPU, memory, and storage utilization across clusters
- **Network Monitoring**: Service mesh observability and traffic patterns

### Application Monitoring
- **Ingress Metrics**: Request rates, response times, and error rates
- **Database Performance**: Connection pooling and query performance
- **Secret Rotation**: Automated monitoring of credential lifecycle

### Planned Enhancements
- **OpenTelemetry**: Distributed tracing and metrics collection
- **Prometheus**: Cluster and application metrics
- **Grafana**: Custom dashboards for platform engineers and developers
- **Alerting**: Proactive notification system for critical issues

## Storage & Database Management

✅ **COMPLETED**: Multi-cluster database provisioning and management system

### Current Implementation

- **CIVO Managed Database**: Shared MySQL database provisioned via Terraform modules
- **GitOps-Based Provisioning**: Database infrastructure managed through ArgoCD ApplicationSets
- **Multi-Cluster Secret Distribution**: AWS Secrets Manager + External Secrets Operator (ESO) for secure credential sync
- **Cross-Cluster Data Consistency**: All clusters connect to the same managed database instance

### Architecture

```
Management Cluster                 Workload Clusters
┌─────────────────┐              ┌─────────────────--┐
│ 1. Terraform    │              │ 4. ExternalSecret │
│    CIVO DB      │              │    (Pull creds)   │
│                 │              │                   │
│ 2. K8s Secret   │              │ 5. App connects   │
│    (DB creds)   │              │    to shared DB   │
│                 │              │                   │
│ 3. PushSecret   │              │                   │
│    (Push to AWS)│              │                   │
└─────────────────┘              └────────────────--─┘
         │                                │
         └────── AWS Secrets Manager ─────┘
```

### Features

- **Automated Database Provisioning**: Terraform modules for CIVO managed databases
- **Secure Credential Management**: ESO PushSecret/ExternalSecret pattern
- **Multi-Cluster Scalability**: New clusters automatically receive database access
- **High Availability**: Built-in failover and backup via CIVO managed service
- **GitOps Compliance**: Entire workflow managed through Git and ArgoCD

### Database Evolution Phases

1. **Phase 1**: Single cluster with PVC-backed MySQL (basic setup)
2. **Phase 2**: Multiple clusters with isolated databases per cluster
3. **Phase 3**: ✅ **CURRENT** - Multiple clusters sharing one managed database
4. **Phase 4**: Multi-cloud managed database with global read replicas

Detailed documentation: [data.md](data.md)

## (TODO) Deploy applications that rely on each other

- Deploy a main "Dashboard" application that relies on secondary "Weather", "Temperature" and "Traffic" applications.
- Each of these "secondary" applications can be deployed on ANY "workload" clusters.
- Provide mechanism for "main" and "secondary" applications to connect with each other cross clusters.

## (TODO) Clusters hardening

Harden via Kubernetes Benchmarks

Use kube-bench to evaluate your cluster against the CIS Kubernetes Benchmark:

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

## (TODO) Costs

https://github.com/kubecost

## References

### Multi-cluster

- https://www.youtube.com/watch?v=4p2YAp5tRM4 (Demo)
- https://github.com/konstructio/navigate/tree/main/2024-austin/registry (Demo source code)
- https://www.getambassador.io/blog/mastering-kubernetes-multi-cluster-availability-scalability#multi-cluster-application-architecture
- https://www.apptio.com/topics/kubernetes/multi-cloud/multi-cluster/
- https://www.tigera.io/learn/guides/kubernetes-networking/kubernetes-multi-cluster/
- https://multicluster.sigs.k8s.io/

### Products

- https://github.com/kubefirst/
- https://linkerd.io/

## Architecture Overview

### Core Components

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **ArgoCD** | GitOps control plane | Manages all cluster provisioning and app deployments |
| **Sealed Secrets** | Secret management | Encrypts secrets for Git storage |
| **External Secrets Operator** | Cross-cluster secrets | Syncs secrets from AWS Secrets Manager |
| **Cert-Manager** | TLS certificate management | Let's Encrypt with DNS-01 challenge |
| **External-DNS** | DNS automation | Cloudflare integration for automatic DNS records |
| **NGINX Ingress** | Traffic routing | Load balancing and SSL termination |
| **Crossplane** | Infrastructure as Code | Terraform provider for cloud resources |

### Multi-Cloud Support

- **Primary Provider**: CIVO (Kubernetes clusters and managed databases)
- **Secondary Provider**: Vultr (additional regions and failover)
- **DNS Provider**: Cloudflare (global DNS management and load balancing)
- **Secrets Provider**: AWS Secrets Manager (cross-cluster credential distribution)

### Cluster Types

**Management Cluster (`in-cluster`)**:
- Hosts ArgoCD server and GitOps control plane
- Provisions and manages all workload clusters
- Runs infrastructure components (Terraform, Crossplane)
- Manages shared resources (databases, load balancers)

**Workload Clusters (`london`, `frankfurt`, `newyork`, etc.)**:
- Hosts user applications and services
- Configured automatically via GitOps
- Receives secrets and configuration from management cluster
- Provides high availability and geographic distribution

## Getting Started

### Prerequisites

- **Cloud Accounts**: CIVO (primary), AWS (secrets), Cloudflare (DNS)
- **Tools**: kubectl, helm, argocd CLI, kubeseal, terraform
- **Credentials**: API tokens for all cloud providers

### Bootstrap Management Cluster

1. **For first time setup:**

```bash
# Set up environment variables
export CIVO_TOKEN="your-civo-token"
export CLOUDFLARE_API_TOKEN="your-cloudflare-token"
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"

# Generate sealed secrets
./scripts/seal-mgmt-secrets.sh

git add 0-crossplane-sealed-secrets.yaml && git commit
```

2. **Provision Management cluster:**

```bash
./scripts/bootstrap-mgmt-cluster-remote.sh
```

3. **Access ArgoCD**:

```bash
# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Access via ingress
open http://localhost:8080 # or https://argocd.automatalife.com
```

4. **Deploy Applications**:

```bash
# Applications will be automatically deployed via GitOps (App of Apps pattern)
# Monitor via ArgoCD UI or CLI
argocd app list
```

### Repository Structure

```
platform/
├── argo/                 # ArgoCD ApplicationSets
│   ├── apps/               # Application definitions
│   ├── clusters/           # Cluster provisioning
│   ├── databases/          # Database provisioning
│   ├── load_balancers/     # LB provisioning
│   └── tools/              # Infrastructure tools
├── bootstrap/            # Initial cluster setup
├── registry/             # GitOps resource registry
│   ├── apps/               # Application Helm charts
│   ├── clusters/           # Cluster-specific configs
│   ├── databases/          # Database configurations
│   └── load_balancers/     # LB configs
├── scripts/              # Automation scripts (Bootstrap workflow)
└── terraform/            # Infrastructure modules
    └── modules/            # Reusable Terraform modules
```

## Key Features & Benefits

### 🚀 **GitOps-Native**
- **Declarative Configuration**: Everything defined as code in Git
- **Automated Deployments**: Zero-touch deployments across all clusters
- **Version Control**: Complete audit trail of all changes
- **Rollback Capability**: Easy rollback to previous known-good states

### 🔒 **Security-First**
- **Encrypted Secrets**: Sealed secrets for Git storage
- **Runtime Secret Injection**: ESO pulls secrets at runtime
- **TLS Everywhere**: End-to-end encryption for all communications
- **RBAC**: Fine-grained access control across all clusters

### 🌐 **Multi-Cloud Ready**
- **Provider Agnostic**: Support for CIVO, Vultr, and extensible to others
- **Global Load Balancing**: Cloudflare-based traffic distribution
- **Cross-Cloud Networking**: Secure communication between cloud providers
- **Disaster Recovery**: Built-in failover and backup strategies

### 📊 **Operational Excellence**
- **Automated Scaling**: Horizontal and vertical scaling policies
- **Health Monitoring**: Continuous health checks and alerting
- **Performance Optimization**: Resource optimization across clusters
- **Cost Management**: Multi-cloud cost optimization strategies

### 🛠️ **Developer Experience**
- **Self-Service Platform**: Developers can deploy without platform team involvement
- **Consistent Environments**: Identical deployment patterns across all clusters
- **Fast Feedback**: Rapid deployment and testing cycles
- **Observability**: Built-in monitoring and debugging tools
