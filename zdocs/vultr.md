# Vultr Kubernetes Cluster Integration (`newyork`)

This guide explains:

- how to provision and connect a remote Kubernetes cluster in **Vultr Cloud**
- using `Crossplane`, `Terraform` and `GitOps` principles.
- It complements the `mgmt-cluster` setup and `toolbox` access strategy used in other providers like `Civo`.

## 1. Use `mgmt-cluster` as a Gateway to `newyork`

* `mgmt-cluster` runs in a public cloud (e.g.: `Civo`) and exposes a `public IP`
* We use this cluster as a **bastion-style gateway** to interact with remote workload clusters (e.g.: `Civo` and `Vultr`)
* A **toolbox pod** is deployed in the `mgmt-cluster` to access remote clusters securely

### 1.1 Access the Toolbox Pod

- Ensure you're pointing to `mgmt-cluster` context (already provisioned by `scripts/bootstrap-mgmt-cluster-remote.sh`):

```bash
unset KUBECONFIG
kubectl config use-context mgmt-cluster
```

```bash
kubectl exec -it toolbox -n default -- bash
```

### 1.2 Extract and Use `newyork` Kubeconfig

```bash
kubectl get secret newyork-kubeconfig -n argocd -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/newyork.kubeconfig
export KUBECONFIG=/tmp/newyork.kubeconfig
kubectl get nodes
```

## 2. Firewall Rules for API Access

`Terraform` config includes logic to dynamically allow access to the `newyork` cluster API (port `6443`)

**only from `mgmt-cluster` public IP**.

Terraform snippet:

```bash
provider "http" {}

data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

locals {
  mgmt_cluster_public_ip_cidr = trimspace(data.http.my_public_ip.response_body)
}

resource "vultr_firewall_rule" "k8s_api" {
  firewall_group_id = vultr_kubernetes.cluster.firewall_group_id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "6443"
  subnet            = local.mgmt_cluster_public_ip_cidr
  subnet_size       = 32
  notes             = "Allow Secure Access to Kubernetes API (e.g.: ArgoCD, kubectl)"
}
```

## 3. ArgoCD Integration

**Terraform automatically** extracts the kubeconfig from `Vultr` cluster and:

* Decodes it
* Creates a Kubernetes secret inside the `mgmt-cluster` in namespace `argocd`
* ArgoCD auto-discovers the cluster and starts syncing apps

## 4. Common Errors and Fixes

### Unauthorized IP Address

If you see within `newyork-infrastructure` workspace in ArgoCD UI:

```
error creating kubernetes cluster: {"error":"Unauthorized IP address: x.x.x.x","status":401}
```

- Make sure `mgmt-cluster` public IP is **whitelisted** in the Vultr dashboard.

> This can happen because Vultr requires **manual API access whitelisting**.

- Go to [Vultr API Settings](https://my.vultr.com/settings/#settingsapi) and add `mgmt-cluster` external IP.

### Monthly Fee Limit Exceeded

If you see within `newyork-infrastructure` workspace in ArgoCD UI:

```
error creating kubernetes cluster: ... You have reached the maximum monthly fee limit for this account ...
```

- Vultr is blocking provisioning because of **account quota limits**.

#### Requesting Limit Increase

Go to the [Vultr Support Page](https://my.vultr.com/support/) and use this message:

> Hello Vultr Support Team,
>
> I am currently working on DevOps learning projects using Vultr Kubernetes Engine (VKE) to explore modern infrastructure provisioning techniques and GitOps workflows. These clusters are **not intended for production**; they are strictly for **educational and research purposes**.
>
> My objective is to expand my DevOps skill set by provisioning Kubernetes clusters, deploying open-source tools, and managing applications through a **GitOps-based setup** (e.g., ArgoCD, Terraform, Crossplane). In order to continue progressing, I would appreciate an increase in my **monthly fee limit** to allow for the creation of additional clusters and environments.
>
> Please let me know if further information is needed. I appreciate support and the excellent services you provide.
>
> Best regards,
> Juan Roldán

### Request Form Fields:

| Field                       | Description                                                   | Example Value |
| --------------------------- | ------------------------------------------------------------- | ------------- |
| **New Instance Limit**      | Max number of instances (VMs or nodes) you want to run        | `10`          |
| **New Instance Cost Limit** | Max monthly compute spend allowance (total for all instances) | `$200`        |

## Summary

* Toolbox pod in `mgmt-cluster` can access `Vultr` workload clusters securely
* `Terraform` handles **kubeconfig generation** and `ArgoCD` **secret registration**
* `API` and `firewall` access is `GitOps-managed` and scoped to trusted IPs
* `Quota` limits in `Vultr` must be monitored and increased as needed

---

This approach ensures a consistent, secure and repeatable workflow to manage `Vultr-based` clusters with GitOps.
