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

### 3. Deploy `Applications`

* Applications are defined declaratively in `registry/clusters/{{cluster}}/apps`.
* A single **ArgoCD ApplicationSet** resource per application keeps apps in sync across clusters and cloud providers.
* Ingress and `TLS` settings are managed inside each cluster's registry folder: `registry/clusters/{{cluster}}/external-dns`

### 4. Diagram

TODO: Add diagram showcasing all 3 points above.

## Applications with External Access

#### How do we install, validate and define Ingress resources GitOps-style?

* Ingress resources are declared within each cluster's registry folder: `registry/clusters/{{cluster}}/ingress-nginx`
* NGINX Ingress Controller is installed via ArgoCD into each workload cluster.
* Ingress is automatically routed via `LoadBalancer` and DNS Manager.

#### How is cert-manager handled for each app?

* A `ClusterIssuer` is defined using `Let’s Encrypt` with `DNS-01` challenge via `Cloudflare`.
* `cert-manager` auto-issues certificates for any ingress using the shared wildcard TLS secret.
* Secrets are managed with **External Secrets Operator** and `GitOps`.

#### How is DNS handled?

* `external-dns` monitors Ingresses and creates `A/TXT` records in `Cloudflare`.
* It authenticates using a shared `Cloudflare API token`, managed with `ESO` and `GitOps`.

#### Can I use `automatalife.com` for secure testing?

* Yes. DNS is managed via Cloudflare.
* For example, `app.london.automatalife.com` is a real test endpoint exposed securely via HTTPS.
* Each cluster (e.g., `london`, `barcelona`, `dublin`) can expose a unique subdomain securely.

#### Quick Local Testing Without DNS Propagation

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

### 5. (TODO) Storage

- How could I provision and manage storage solutions for my multi-cluster platform ?
- What are the solutions to implement? (local setup / cloud solution: CIVO, Vultr)
- Define a sample application that relies on database (e.g.: `Ghost` blog).

### 6. (TODO) Failover solutions

- I'd like to define 2 clusters in different cloud providers running `workload` applications.
- Have traffic being load-balanced between these 2 clusters.
- Then shutdown 1 cluster and see how traffic is re-routed 100% to the other cluster in real time.
- Then provision back again the cluster and see how traffic is re-routed back to 50/50 between `workload` clusters.
- Include scenarios to handle applications that rely on databases (e.g.: `Ghost` blog) and provide solution around DB backups and restore.

### 7. (TODO) Clusters hardening

Harden via Kubernetes Benchmarks

Use kube-bench to evaluate your cluster against the CIS Kubernetes Benchmark:

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

### 7. (TODO) Costs

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
