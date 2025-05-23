# platform

This repository is built on top of all achievements made within [gitops-manifests-repo](https://github.com/juanroldan1989/gitops-manifests-repo).

This [platform](https://github.com/juanroldan1989/platform) repository is built to expand those achievements and make them more scalable:

- This repository is meant to define a **"management" cluster** to be up and running

- Within this "mangement" cluster, `ArgoCD` (or other tools, please advise) is provisioned and takes care of **detecting** changes to `platform/manifests`, selecting **the right cluster** and provisioning/updating the **correct K8S application.**

- Now, this leads to one question: how should I provision this "management" cluster in the first place? under which folder/environment structure? k3ds could be a solution for this.

## Introduction

This [platform](https://github.com/juanroldan1989/platform) repository goal is to manage Kubernetes-based application environments using GitOps principles.

This repository provides the foundational tooling and infrastructure automation to support development teams deploying to `DEV`, `TEST` and `PROD` environments.

## Goals

This repository's mission is to **enable a streamlined, scalable and self-service platform** where:

1. Application teams focus solely on developing their apps (within separate github app repositories, e.g.: `applicatioins` repo)

2. Within this `platform` github repository, Platform engineers follow `GitOps` principles to define:

- MGMT Cluster
- Workload Clusters
- Applications running in which clusters
- Interface to manage all this (it could be argocd running within MGMT Cluster, it could be Rancher, etc)

3. GitOps ensures transparency, traceability and automation across all environments (`DEV/TEST/PROD`)

## `platform` repo - Setup to contain (local / cloud)

### 1. Management cluster

- Automate `mgmt-cluster` provisioning (local setup / cloud solution: CIVO)
- Automate `mgmt-cluster` configuration (installing addons: ESO, Cert-Manager, DNS manager, NGINX Ingress, etc)
- Bottom line goal is to eliminate manual scripts as much as possible.

### 2. Workload clusters

- Apply GitOps to the process of provisioning `workload` clusters (`dev`, `test`, `prod`).
- Automate process of registering `workload` clusters within `ArgoCD` server in `mgmt-cluster`.
- Automate process of configuring `workload` clusters (installing all addons needed)
- Bottom line goal is to eliminate manual scripts as much as possible.

### 3. Deploy applications

- Automate `applications` deployment from `platform/manifests` folder witin their respective `workload` clusters (`dev`, `test`, `prod`).

### 4. Applications that need to provide external access for users

- How could I install, validate and define an ingress resource for each of my applications that needs it, in a GitOps way ?
- How could I handle cert-managers for each ingress resource in a GitOps way ?
- How could I handle DNS for each ingress resource in a GitOps way ?
- I've already got an automatalife.com domain registered within Cloudflare.
- How could I use this domain for future testing of my applications to provision secure endpoints to try accessing applications ?

### 5. Storage

- How could I provision and manage storage solutions for my multi-cluster platform ?
- What are the solutions to implement? (local setup / cloud solution: CIVO)

### 6. Failover solutions

- I'd like to define 2 clusters running `workload` applications
- Have traffic being load-balanced between these 2 clusters
- Then shutdown 1 cluster and see how traffic is re-routed 100% to the other cluster
- Then provision back again the cluster and see how traffic is re-routed back to 50/50 between `workload` clusters.

### 5. Costs

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
