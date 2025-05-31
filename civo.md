# London Cluster Setup (CIVO Cloud)

This document describes how to extract the `london` cluster kubeconfig, connect to it locally, restore your `k3d`-based management context, and understand the networking and GitOps configuration between your local ArgoCD instance and the remote `london` cluster on CIVO Cloud.

---

## 1. Extracting the `london` kubeconfig and using it locally

1. List the secrets from the namespace where your workspace is running (e.g. `argocd` or Crossplane-managed namespace):

```bash
kubectl get secret -n argocd
```

2. Extract the kubeconfig from the `london-kubeconfig` secret:

```bash
kubectl get secret london-kubeconfig -n argocd -o jsonpath='{.data.value}' | base64 -d > london.kubeconfig
```

3. Use it locally by setting the environment variable:

```bash
export KUBECONFIG=./london.kubeconfig
```

4. Confirm access to the cluster:

```bash
kubectl config get-contexts
kubectl get nodes
```

---

## 2. Resetting KUBECONFIG to local k3d `mgmt-cluster`

If you want to return to using your local management cluster:

```bash
unset KUBECONFIG
kubectl config use-context k3d-mgmt-cluster
```

---

## 3. ArgoCD connection to the `london` cluster

Your local `k3d-mgmt-cluster` runs ArgoCD.

The `london` cluster is added via `argocd cluster add` using its external API address (e.g. `https://74.220.23.87:6443`).

ArgoCD connects via Token/Basic Auth credentials stored from the extracted kubeconfig and uses that to sync applications to the remote cluster.

This connection is visible in the ArgoCD UI under the **Settings > Clusters** section, where the `london` cluster will appear as healthy if accessible.

---

## 4. CIVO Firewall Configuration for ArgoCD Connectivity

To ensure ArgoCD can communicate with the `london` cluster API and that sync operations succeed, you need to:

* Allow **TCP port 6443** from the **host machine's IP** (where the local `k3d` cluster runs).
* Optionally allow **TCP port 22** if you use SSH for troubleshooting.
* Ensure **port 443 and 80** are open from `0.0.0.0/0` for ingress purposes.

Example Inbound Rules on CIVO Firewall:

| Protocol | Port | Source CIDR      | Purpose        |
| -------- | ---- | ---------------- | -------------- |
| TCP      | 6443 | your.local.ip/32 | Kubernetes API |
| TCP      | 80   | 0.0.0.0/0        | HTTP ingress   |
| TCP      | 443  | 0.0.0.0/0        | HTTPS ingress  |

Once these are set, ArgoCD will report the `london` cluster as **healthy**, and sync operations like installing `ingress-nginx` will succeed.

---

## 5. Tools/Addons to be Installed in `london`

The following tools and addons are being installed (or are planned) within the `london` cluster:

| Tool             | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `ingress-nginx`  | HTTP ingress controller for routing external traffic |
| `external-dns`   | Automatic DNS updates via Cloudflare API             |
| `cert-manager`   | SSL certificate automation via Let's Encrypt         |
| `sealed-secrets` | Encrypt Kubernetes secrets for GitOps workflows      |
| `metrics-server` | HPA metrics (CPU/Memory) support                     |

All of these are deployed using ArgoCD `Application` manifests with cluster-specific value overrides.

---

This setup allows full GitOps-based lifecycle management of the `london` workload cluster from your local `mgmt-cluster`, maintaining clear separation and scalability across environments.
