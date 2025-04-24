# platform

This repository is built on top of all achievements made within [gitops-manifests-repo](https://github.com/juanroldan1989/gitops-manifests-repo).

Also, [gitops-manifests-repo](https://github.com/juanroldan1989/gitops-manifests-repo) presents certains limitations.

This [platform](https://github.com/juanroldan1989/platform) repository is built to tackle those limitations:

- Deploy **different versions** of the **a K8S application** across **different environments/clusters.**

- Define a way to persist **which K8S applications are provisioned on each environment**. Facilitating disaster recovery strategies.

- The usage of **ArgoCD ApplicationSet** can be really useful when dealing with **1 K8S app deployed across different environments/clusters** (e.g.: `DEV/TEST/PROD` clusters).

-- At the same time, this approach requires for a **specific "management" cluster** to be up and running

-- Within this "mangement" cluster, `ArgoCD` is provisioned and takes care of **detecting** changes to manifests, selecting **the right cluster** and provisioning/updating the **correct K8S application.**

-- Now, this leads to the question: how should I provision this "management" cluster in the first place? under which folder/environment structure?

-- Also, how should I provision resources a `sample-app` might need? (e.g.: `postgres` database, `redis` cache, `S3` bucket, etc.) in a secure, automated and scalable way, considering running hundreds of applications.

## Introduction

This [platform](https://github.com/juanroldan1989/platform) repository represents the central control plane for managing Kubernetes-based application environments using GitOps principles.

This repository provides the foundational tooling and infrastructure automation to support development teams deploying to `DEV`, `TEST` and `PROD` environments.

## Goals

This repository's mission is to **enable a streamlined, scalable and self-service platform** where:

- Application teams focus solely on developing their apps.

- Platform engineers define and maintain infrastructure as code.

- GitOps ensures transparency, traceability and automation across all stages.

## Sequence of steps regarding `platform` repo (local / cloud)

### 1. Management cluster

Automate `mgmt-cluster` provisioning and configuration.

### 2. Workload clusters

- Automate `workload` clusters (`dev`, `test`, `prod`) provisioning and configuration via `mgmt-cluster`.
- Register `workload` clusters within `ArgoCD` in `mgmt-cluster`.

### 3. Deploy applications

- Automate `applications` deployment from `manifests` witin their respective `workload` clusters (`dev`, `test`, `prod`).
