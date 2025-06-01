# CIVO Kubernetes Cluster Integration (`london`)

This document outlines:

- how to access the remote `london` Kubernetes cluster hosted on `CIVO` Cloud
- using a `GitOps-first approach` and `mgmt-cluster` as a secure control plane

For references:

- `mgmt-cluster` is hosted in CIVO cloud
- `workload` clusters are hosted in CIVO cloud (`london`) and Vultr cloud (`newyork`)

## Use `mgmt-cluster` as a Trusted Gateway (Toolbox Pod as a Bastion)

Since:

- `mgmt-cluster` has firewall access to `london` cluster's Kubernetes API (port `6443`)

- `ArgoCD` is deployed inside `mgmt-cluster`

- Infrastructure is provisioned via **GitOps (ArgoCD + Crossplane + Terraform)**

We introduce a **lightweight toolbox pod** that acts as a bastion container inside the `mgmt-cluster`

Allowing access to any workload cluster (e.g.: `london`) securely and without exposing your local machine.

### Why a Toolbox pod?

- Avoid whitelisting local IP in `Civo` firewall rules

- Perform **debugging** or apply temporary commands securely

- **GitOps-friendly:** defined as a YAML manifest inside the repo

### 1. Access the toolbox pod inside mgmt-cluster

- Ensure you're pointing to `mgmt-cluster` context (already provisioned by `scripts/bootstrap-mgmt-cluster-remote.sh`):

```bash
unset KUBECONFIG
kubectl config use-context mgmt-cluster
```

- Exec into the running `toolbox` pod:

```bash
kubectl exec -it toolbox -n default -- bash
```

### 2. Extract and use `london` kubeconfig

When a new cluster like `london` is provisioned via Terraform,

its `kubeconfig` is automatically stored as a Kubernetes secret inside the `argocd` namespace of the `mgmt-cluster`.

To retrieve and use it within `toolbox` pod:

- Extract kubeconfig into a writable path:

```bash
I have no name!@toolbox:/$ kubectl get secret london-kubeconfig -n argocd -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/london.kubeconfig
```

- Point kubeconfig environment variable to it:

```bash
I have no name!@toolbox:/$ export KUBECONFIG=/tmp/london.kubeconfig
```

- Confirm access:

```bash
I have no name!@toolbox:/$ kubectl get nodes
NAME                                          STATUS   ROLES    AGE   VERSION
k3s-london-1645-cd5830-node-pool-9f8b-ho3in   Ready    <none>   53m   v1.28.7+k3s1
k3s-london-1645-cd5830-node-pool-9f8b-r7pdw   Ready    <none>   53m   v1.28.7+k3s1
k3s-london-1645-cd5830-node-pool-9f8b-v5coe   Ready    <none>   53m   v1.28.7+k3s1
```

```bash
I have no name!@toolbox:/$ kubectl get po -A
NAMESPACE       NAME                                               READY   STATUS    RESTARTS   AGE
kube-system     civo-ccm-5474f5869d-qww6f                          1/1     Running   0          53m
kube-system     coredns-6799fbcd5-swj59                            1/1     Running   0          53m
kube-system     civo-csi-node-29xhr                                2/2     Running   0          53m
kube-system     civo-csi-node-v8bls                                2/2     Running   0          53m
kube-system     otel-collector-j2zlk                               1/1     Running   0          53m
kube-system     civo-csi-node-lj2p7                                2/2     Running   0          53m
kube-system     otel-collector-kct4m                               1/1     Running   0          53m
kube-system     otel-collector-lsbhs                               1/1     Running   0          53m
kube-system     civo-csi-controller-0                              4/4     Running   0          53m
ingress-nginx   ingress-nginx-london-controller-579bd98bf5-vnxml   1/1     Running   0          52m
```

### 4. Validate access to Management Cluster (`mgmt-cluster`)

- Exit `toolbox`

- Check kubeconfig setup is correct:

```bash
unset KUBECONFIG
kubectl config use-context mgmt-cluster
```

## How ArgoCD registers `london` cluster (fully automated)

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

## Firewall Rules: Dynamic Allowlist for ArgoCD Control Plane

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

## Tools and Addons installed into the `london` cluster

- The following addons are provisioned declaratively via **ArgoCD ApplicationSets** and **environment-specific** value overrides:

| Tool             | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `ingress-nginx`  | HTTP ingress controller for routing external traffic |
| `external-dns`   | Automatic DNS updates via Cloudflare API             |
| `cert-manager`   | SSL certificate automation via Let's Encrypt         |
| `sealed-secrets` | Encrypt Kubernetes secrets for GitOps workflows      |
| `metrics-server` | HPA metrics (CPU/Memory) support                     |

- These apps are deployed into the `london` cluster only after it has been registered and marked healthy by `ArgoCD`.

## Sync Wave Behavior: Handling timing for remote clusters (`london`)

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

## Summary

- Entire cluster provisioning is **declarative and automated**

- Cross-cluster communication is secured via **dynamic firewall allowlists**

- `ArgoCD` **connects and syncs to remote clusters** without manual steps

- All infrastructure state is stored via **Git + Kubernetes-native secrets**

---

This setup allows full GitOps-based lifecycle management of the `london` workload cluster from local `mgmt-cluster`, maintaining clear separation and scalability across environments.
