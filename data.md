# Data Management in CIVO: Kubernetes Volumes vs Cloud Databases

This document summarizes the architecture, storage mechanisms and trade-offs between:

- running databases inside Kubernetes clusters using Persistent Volumes versus
- using cloud-managed databases like CIVO's DBaaS.

## Current Setup: MySQL Inside Kubernetes with PVCs

You currently run a Ghost blog application in two CIVO Kubernetes clusters (`london`, `frankfurt`). Each cluster includes:

* A **MySQL** database deployed via the Bitnami Helm chart.
* **Ghost** connected to the local in-cluster MySQL.
* **PersistentVolumeClaims (PVCs)** used to persist the MySQL data.
* **External Secrets Operator (ESO)** to inject DB credentials securely from AWS Secrets Manager.

Each database stores blog posts, users and other Ghost metadata in a local volume.

## Where Is My Data Stored Now?

In both the `london` and `frankfurt` clusters:

* Ghost content is stored in a `1Gi` PVC mounted at `/var/lib/ghost/content`.
* MySQL data is stored in a `5Gi` PVC provisioned by CIVO.

These `PVCs` are backed by CIVO's native block storage volumes, managed by the CSI driver in each Kubernetes cluster.

The volumes are visible in CIVO dashboard under the "Volumes" section.

## What's the Difference? Volumes vs Managed DBs

| Feature                         | Kubernetes PVC + Volumes + MySQL                     | CIVO Managed Database (DBaaS)                      |
|---------------------------------|------------------------------------------------------|----------------------------------------------------|
| **MySQL runs in**               | Inside Kubernetes cluster (as a pod)                 | Outside the cluster, managed by the provider       |
| **Data Storage**                | In PVCs (block storage volumes in CIVO)              | Provider-managed persistent storage                |
| **Backups**                     | You need to set up and automate                      | Provided by default (or easily enabled)            |
| **Networking**                  | Inside cluster only (e.g. `mysql.svc.cluster.local`) | Exposed via private/public endpoint, more portable |
| **High Availability (HA)**      | You must configure StatefulSets/replication          | Built-in, depending on tier                        |
| **Replication across clusters** | Complex to set up (e.g., Galera, binlog replication) | Might be available via provider                    |
| **Maintenance**                 | Your responsibility (version upgrades, tuning)       | Managed by provider                                |
| **Cost**                        | Lower infra cost, but more DevOps effort             | Higher cost, lower ops burden                      |
| **GitOps friendly**             | Fully manageable via Helm, ESO, ArgoCD               | Partially (requires Terraform/API for provisioning)|
| **Scaling**                     | Manual (resource requests, StatefulSet)              | Automated/managed                                  |
| **Failover**                    | Requires multi-node coordination                     | Built-in failover options                          |
| **Security**                    | Your TLS, firewall, IAM, secrets management          | Provider-managed access & policies                 |

## PVC Sizes Breakdown

Your Helm values specify the size of each PVC:

```yaml
primary:
  persistence:
    enabled: true
    size: 5Gi
```

This corresponds to the `5Gi` volume shown in the CIVO UI. Similarly, Ghost's `1Gi` PVC is for storing content uploads and themes.

## Understanding Database Storage in `Kubernetes` vs. `Managed Cloud Services`

### Kubernetes Volume (PVC) Storage — What It Is, Lifecycle, Pros and Cons

- In Kubernetes, a **volume** represents a piece of **persistent storage** that a Pod can use to store and retrieve data **across restarts**.

- A volume in Kubernetes is typically backed by a **PersistentVolume (PV)** provisioned dynamically

through a **PersistentVolumeClaim (PVC)** and a **StorageClass**.

- When using a provider like **CIVO**, the volume is created using the `CSI (Container Storage Interface)` driver,

which **interfaces with the cloud provider’s native block storage** (like `CIVO's volume API`).

#### Lifecycle of Data

* When a PVC is created, CIVO provisions a block storage volume and attaches it to the node where the pod is scheduled.
* The pod can **read/write** to the mounted volume.
* If the pod restarts, Kubernetes will reattach the volume.
* If the pod is deleted but the PVC remains, the volume still exists.
* If the PVC is deleted, the PV (and underlying volume) will be **deleted** if the reclaim policy is `Delete`.

#### Pros

* Fast to set up using Helm charts like Bitnami's MySQL.
* Entirely GitOps-driven.
* Cheaper than managed services.
* Storage is close to compute (low-latency).
* Fully inside your Kubernetes cluster (easy to backup with Velero, etc).

#### Cons

* Single point of failure: if the cluster is lost, the data might be gone unless externally backed up.
* Scaling vertically (e.g., increasing volume size) requires pod restarts.
* **No built-in HA** or cross-region replication.
* DB performance tuning is your responsibility (CPU, IO limits).

### Managed Database (Outside the Cluster) — What It Is, Pros and Cons

- A **managed database** is a **fully provisioned and maintained service** offered by a cloud provider (e.g., AWS RDS, CIVO Managed DB).

- You don't need to install MySQL yourself. Instead, you interact with it over the network.

- It lives **outside your Kubernetes cluster**, often within the same cloud provider’s private network or VPC.

#### Pros

* Built-in backups, failover, and replication.
* Cross-AZ high availability.
* You don't manage storage, upgrades or patching.
* Better long-term scaling.
* Access from multiple clusters (read replicas, etc).

#### Cons

* More expensive (you pay for availability, snapshots, etc).
* Slower to set up in a GitOps way (provider-specific APIs).
* Slightly higher latency due to network communication.
* Cross-provider portability is more complex.

---

## Phases of Database Evolution (for Multi-Cluster `Blog` App)

### **Phase 1 — One Cluster, DB Inside Cluster (PVC + Helm Chart)**

- Your `Blog` application and `MySQL` database both live inside the same Kubernetes cluster.

- MySQL is deployed using the `Bitnami Helm` chart with a `PersistentVolumeClaim` (PVC).

- `CIVO` dynamically provisions the backing volume.

|          |                                                                                     |
| -------- | ----------------------------------------------------------------------------------- |
| **Pros** | Fast setup, fully in GitOps, everything inside Kubernetes.                          |
| **Cons** | If cluster fails, data is lost unless you back it up manually. Not portable. No HA. |

---

### **Phase 2 — One Cloud Provider, Multiple Clusters, One DB Per Cluster**

- Each cluster has its own instance of the MySQL DB using a PVC, like in `London` and `Frankfurt`.

- They do **not** sync data across clusters.

- This enables app failover but **not** data continuity.

|          |                                                                                                              |
| -------- | -------------------------------------------------------------------------------------------------------------|
| **Pros** | Redundant app hosting. `Blog` accessible globally. No cross-region networking.                               |
| **Cons** | Data is **isolated per region**. No central source of truth. Changes in `London` don't reflect in Frankfurt. |

---

### **Phase 3 — One Cloud Provider, Multiple Clusters, One Shared Managed DB**

- Move `MySQL` to CIVO's managed DB offering.

- Each cluster connects to the same MySQL endpoint securely (e.g.: through DNS, VPC Peering, or private IP).

- **This centralizes data.**

|          |                                                                                                       |
| -------- | ------------------------------------------------------------------------------------------------------|
| **Pros** | Single source of truth. No data drift. Built-in availability. **Data safe even if clusters go down.** |
| **Cons** | Higher cost. Networking complexity. Data security (must secure access).                               |

---

### **Phase 4 — Multi-Cloud, Multi-Cluster, Shared Managed DB**

1. Move DB to a **globally accessible managed service** (e.g.: `AWS RDS with read replicas`, or `Cloud SQL via private IP`)

2. Allow **read/write** from clusters in different cloud providers (e.g.: `CIVO`, `Vultr`).

3. Use encryption + latency-aware routing.

|          |                                                                                |
| -------- | ------------------------------------------------------------------------------ |
| **Pros** | True cloud-agnostic resilience. Global HA. Ideal for failover + availability.  |
| **Cons** | Most complex setup. Cross-cloud networking, IAM, TLS certs, firewalls. Costly. |

---

# Kubernetes Volumes: Behind the Scenes

## Where Is the Data Actually Stored?

- When you provision a `PersistentVolumeClaim (PVC)` in your `CIVO` Kubernetes cluster, you're asking the cluster to allocate block storage from CIVO's infrastructure.

This is what happens under the hood:

1. CIVO uses a Container Storage Interface (CSI) driver to provision a network-attached volume — not a local directory inside the node.

2. This volume is hosted in CIVO's cloud storage backend, separate from your cluster nodes. It's attached at runtime to the worker node where the pod is scheduled.

3. On the node, the volume is mounted at something like:

```
/var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~csi/
```

- This makes the data:

1. Durable across pod restarts

2. Retained as long as the PVC exists

3. Persistent even if the pod or node is deleted

## Lifecycle of a PVC-backed Volume

| **Action**                         | **Outcome**                                                |
| ---------------------------------- | -----------------------------------------------------------|
| Pod is deleted                     | PVC remains, volume remains, data is safe                  |
| Pod is rescheduled to another node | Volume is detached from old node and reattached to new one |
| PVC is deleted (Reclaim: Delete)   | Volume is deleted — data is permanently lost               |
| PVC is deleted (Reclaim: Retain)   | Volume remains orphaned — you can manually recover         |
| Node fails                         | Kubernetes tries to remount the volume on a healthy node   |

---

## Pros and Cons of Volume-Based Storage (Inside the Cluster)

| Pros                                                 | Cons                                                           |
| ---------------------------------------------------- | -------------------------------------------------------------- |
| No need for external services                        | Single writer per volume (RWO mode) limits scalability         |
| Fully GitOps-compatible (via Helm/ArgoCD/ESO)        | Data durability depends on cloud provider’s volume reliability |
| Fast local access inside cluster                     | HA and backups must be manually set up                         |
| Portability and dynamic provisioning (PVC templates) | Volume is tied to a specific cluster (not multi-cluster)       |

---

## Where Does Ghost Store Its Data?

Ghost stores data in two distinct layers:

### 1.Structured Content (Posts, Users, Tags, Pages)

| **Aspect**          | **Details**                                                                    |
| ------------------- | ------------------------------------------------------------------------------ |
| **Storage**         | MySQL database (`ghost_db`)                                                    |
| **Contents**        | Posts, pages, users, tags, metadata                                            |
| **Synchronization** | Centralized — all replicas can access the same state                           |
| **Location**        | In your setup, stored in the `blog-db` MySQL StatefulSet (CIVO Volume via PVC) |
| **Behavior**        | Fully safe to share across app replicas and clusters                           |

### 2. Media Files (Images, Uploads, Attachments)

| **Aspect**      | **Details**                                                                                         |
| --------------- | --------------------------------------------------------------------------------------------------- |
| **Storage**     | By default, saved to the filesystem (`/var/lib/ghost/content`)                                      |
| **Persistence** | Backed by a PVC (CIVO volume) attached to the pod                                                   |
| **Problem**     | If you scale to multiple pods, only one can write/read due to `ReadWriteOnce` (RWO) limitations     |
| **Risk**        | Not safe for multi-replica setups — may lead to data access issues                                  |
| **Solution**    | Use object storage like AWS S3, MinIO, or CIVO Object Store and configure Ghost to use that backend |

### Summary

- Your **posts, users, and pages are already centralized and scalable** via MySQL (great setup).
- Your **media files are not yet scalable** — to make your app multi-replica and cross-cluster safe, consider moving to object storage.
