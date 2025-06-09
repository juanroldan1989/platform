# platform

This repository is built on top of all achievements made within [gitops-manifests-repo](https://github.com/juanroldan1989/gitops-manifests-repo).

This [platform](https://github.com/juanroldan1989/platform) repository expands those achievements and makes them more scalable and production-ready:

* This repository defines and provisions a **"management cluster"**.
* Within this "management" cluster, `ArgoCD` is provisioned and takes care of **detecting** changes in the `platform/registry` folder, selecting **the right workload cluster**, and provisioning/updating the **correct Kubernetes application**.

## How is the "management" cluster provisioned?

The management cluster is provisioned using the script `./scripts/bootstrap-mgmt-cluster-remote.sh`.

It runs against `CIVO` Cloud and installs `ArgoCD`, `Sealed Secrets` and other essential tools.

---

## Introduction

The [platform](https://github.com/juanroldan1989/platform) repository is built to manage Kubernetes-based application environments using GitOps principles.

It provides foundational infrastructure and automation to support deploying applications in `DEV`, `TEST`, and `PROD` environments.

---

## Goals

This repository's mission is to **enable a streamlined, scalable and self-service platform** where:

1. Application teams focus solely on developing their apps in separate repositories (e.g.: `applications` repo).

2. Platform engineers use this `platform` repository to follow GitOps practices and define:

   * MGMT Cluster
   * Workload Clusters
   * Applications and their target clusters
   * A GitOps control plane (ArgoCD in the MGMT cluster)

3. GitOps ensures **transparency**, **traceability** and **automation** across all environments (DEV / TEST / PROD) and clusters (london, barcelona, dublin)

---

## `platform` Repo – Setup (Local / Cloud)

### 1. Management Cluster

* Provisions a `mgmt-cluster` automatically using CIVO or a local setup.
* Configures core tools: ArgoCD, Sealed Secrets, Cert-Manager, External-DNS and NGINX Ingress.
* Removes the need for manual scripts wherever possible.

### 2. Workload Clusters

* Applies GitOps to provision `workload clusters` such as `london`, `barcelona` and `dublin`.
* Registers each workload cluster in ArgoCD via GitOps automation.
* Configures each cluster with required addons like ESO, Ingress-NGINX, cert-manager, etc.
* Follows the same GitOps flow to minimize manual interaction.

### 3. Deploy Applications

* Applications are defined declaratively in `registry/clusters/{{cluster-name}}/apps`.
* A single ArgoCD `Application` resource per app keeps apps in sync across environments.
* Ingress and TLS settings are managed inside the app definition (e.g., `app.yaml`).

### 4. Applications with External Access

#### ✅ How do we install, validate, and define Ingress resources GitOps-style?

* Ingress resources are declared in each app’s manifest YAML.
* NGINX Ingress Controller is installed via ArgoCD into each workload cluster.
* Ingress is automatically routed via `LoadBalancer` and DNS.

#### ✅ How is cert-manager handled for each app?

* A `ClusterIssuer` is defined using Let’s Encrypt with DNS-01 challenge via Cloudflare.
* cert-manager auto-issues certificates for any ingress using the shared wildcard TLS secret.
* Secrets are managed with External Secrets Operator and GitOps.

#### ✅ How is DNS handled?

* `external-dns` monitors Ingresses and creates A/TXT records in Cloudflare.
* It authenticates using a shared Cloudflare API token, managed with ESO and GitOps.

#### ✅ Can I use automatalife.com for secure testing?

* Yes. DNS is managed via Cloudflare.
* For example, `app.london.automatalife.com` is a real test endpoint exposed securely via HTTPS.
* Each region (e.g., `london`, `barcelona`, `dublin`) can expose a unique subdomain securely.

#### 🧪 Bonus: Quick Local Testing Without DNS Propagation

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

---

### 5. (WIP) Storage

- How could I provision and manage storage solutions for my multi-cluster platform ?
- What are the solutions to implement? (local setup / cloud solution: CIVO)

### 6. (WIP) Failover solutions

- I'd like to define 2 clusters running `workload` applications
- Have traffic being load-balanced between these 2 clusters
- Then shutdown 1 cluster and see how traffic is re-routed 100% to the other cluster
- Then provision back again the cluster and see how traffic is re-routed back to 50/50 between `workload` clusters.

### 7. (WIP) Costs

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
