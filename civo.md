# CIVO Cluster Integration Guide (`london` Example)

This document outlines how to interact with remote Kubernetes cluster hosted on [CIVO Cloud](https://www.civo.com):

- how to extract kubeconfig access

- how to restore local context (`mgmt-cluster`)

- how `london` workload cluster gets automatically registered in ArgoCD, running inside cloud management plane.

## 1. Extract and use `london` kubeconfig locally

When a new cluster like `london` is provisioned via Terraform,

its kubeconfig is automatically stored as a Kubernetes secret inside the `argocd` namespace of the `mgmt-cluster`.

To manually retrieve and use it:

```bash
# 1. Extract kubeconfig to local file
kubectl get secret london-kubeconfig -n argocd -o jsonpath='{.data.kubeconfig}' | base64 -d > london.kubeconfig

# 2. Point KUBECONFIG to it
export KUBECONFIG=$PWD/london.kubeconfig

# 3. Confirm access
kubectl config get-contexts
kubectl get nodes
```

## 2. Restore Access to Local Management Cluster (`mgmt-cluster`)

If you want to return to using management cluster:

```bash
unset KUBECONFIG
kubectl config use-context mgmt-cluster
```

## 3. How ArgoCD registers `london` cluster (fully automated)

Terraform module includes logic that:

- Reads the kubeconfig from the newly created `civo_kubernetes_cluster.london` resource

- Parses the `CA`, `client certificate` and `key`

- Creates a `Kubernetes Secret` of type `Opaque` inside `mgmt-cluster/argocd` with this structure:

```yaml
metadata:
  name: london
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
data:
  name: london
  server: https://<external-api-endpoint>:6443
  clusterResources: true
  config:
    tlsClientConfig:
      insecure: false
      caData: <...>
      certData: <...>
      keyData: <...>
```

- This secret is picked up by `ArgoCD` automatically

- and the `london` cluster will appear in the `Settings > Clusters` view within the UI.

- ArgoCD connects via `Token/Basic` Auth credentials stored from the extracted `kubeconfig`

- and uses that to `sync` applications to the `remote` cluster.

## 4. Firewall Rules: Dynamic Allowlist for ArgoCD Control Plane

To ensure ArgoCD can reach the `Civo` API server of `london` cluster,

we dynamically allow the `public IP` of `mgmt-cluster` into the firewall rules.

- This is automated via Terraform using:

```sh
ingress_rule {
  label      = "allow-k8s-api"
  protocol   = "tcp"
  port_range = "6443"
  cidr       = [local.mgmt_cluster_public_ip_cidr] # "mgmt-cluster" Civo Cluster's External IP
  action     = "allow"
}
```

This guarantees connectivity for `ArgoCD` to connect over the Kubernetes API and perform:

1. `health checks`
2. **tools provisioning**
3. **applications deployment**

## 5. Tools and Addons installed into the `london` cluster

- The following addons are provisioned declaratively via **ArgoCD ApplicationSets** and **environment-specific** value overrides:

| Tool             | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `ingress-nginx`  | HTTP ingress controller for routing external traffic |
| `external-dns`   | Automatic DNS updates via Cloudflare API             |
| `cert-manager`   | SSL certificate automation via Let's Encrypt         |
| `sealed-secrets` | Encrypt Kubernetes secrets for GitOps workflows      |
| `metrics-server` | HPA metrics (CPU/Memory) support                     |

- These apps are deployed into the `london` cluster only after it has been registered and marked healthy by `ArgoCD`.

## 6. Sync Wave Behavior: Handling timing for remote clusters (`london`)

Since the entire provisioning process is **fully GitOps-managed**,

`ingress-nginx` and other apps **wait until london is healthy.**

ArgoCD's `sync-wave` mechanism ensures that:

- Workload clusters are provisioned **(wave 0–10)**

- Clusters are registered in ArgoCD via Secret **(wave 15–20)**

- Ingress, DNS, cert-manager and applications are applied **only after ArgoCD can connect to the remove cluster (wave 50+)**

Example ApplicationSet snippet:

```yaml
metadata:
  name: ingress-nginx
  annotations:
    argocd.argoproj.io/sync-wave: "50"
spec:
  generators:
    - list:
        elements:
          - name: london
            namespace: ingress-nginx
```

## 7. Summary

- Entire cluster provisioning is **declarative and automated**

- Cross-cluster communication is secured via **dynamic firewall allowlists**

- `ArgoCD` **connects and syncs to remote clusters** without manual steps

- All infrastructure state is stored via **Git + Kubernetes-native secrets**

---

This setup allows full GitOps-based lifecycle management of the `london` workload cluster from local `mgmt-cluster`, maintaining clear separation and scalability across environments.
