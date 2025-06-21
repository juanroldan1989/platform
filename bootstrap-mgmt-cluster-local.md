# Bootstrap `mgmt-cluster` in local machine

### Prerequisites

- k3d: local kubernetes
  - install: `brew install k3d`
- watch: repeat a command to watch resources
  - install: `brew install watch`
- kubectl: interact with kubernetes
  - install: `brew install kubectl`
- civo account
  - set nameserver records at your domain registrar to `ns0.civo.com` and `ns1.civo.com`
  - add your domain in your [civo dns](https://dashboard.civo.com/dns)

### Clone `platform` repository

```sh
git clone https://github.com/juanroldan1989/platform
cd platform
```

## Step 1: Management Cluster

### 1.1 create a local bootstrap cluster

- We use `k3d` to provision `mgmt-cluster` that will need a `CIVO_TOKEN` added as a kubernetes secret.

- This `mgmt-cluster` will also have additional manifests that install `argocd` to the new cluster with a few default configurations.

#### Creating `mgmt-cluster` for the first time:

1. Create cluster:

```sh
k3d cluster create mgmt-cluster \
  --agents "2" \
  --agents-memory "4096m" \
  --volume $PWD/manifests/bootstrap-k3d.yaml:/var/lib/rancher/k3s/server/manifests/bootstrap-k3d.yaml
```

2. Extract `public-key` associated with `Sealed Secrets`:

3. Store this `public-key` within `./sealed-secrets/sealed-secrets-key.yaml`

#### Creating `mgmt-cluster` for future times:

1. Create cluster (include `public key` for `Sealed Secrets`):

```sh
k3d cluster create mgmt-cluster \
  --agents "2" \
  --agents-memory "4096m" \
  --volume $PWD/manifests/bootstrap-k3d.yaml:/var/lib/rancher/k3s/server/manifests/bootstrap-k3d.yaml \
  --volume $PWD/.sealed-secrets:/platform/.sealed-secrets
```

---

The result will be a **local bootstrap k3d cluster** with the necessary components **for app and infrastructure management**.

### 1.2 Cloud Provider API Tokens

**These steps are only necessary for the first time mgmt-cluster is created**

- [Civo Dashboard](https://dashboard.civo.com/security)
- [Vultr Dashboard](https://my.vultr.com/settings/#settingsapi)

```sh
export CIVO_TOKEN=xxxxxxxx
export VULTR_TOKEN=xxxxxxxx
```

These tokens will be used by the `crossplane terraform provider` to allow provisioning of:

1. `CIVO` and `Vultr` cloud infrastructure
2. external-dns to create and adjust DNS records in those accounts.
3. Run the `./scripts/seal-secret.sh`
4. Commit changes made to `manifests/bootstrap/crossplane/0-crossplane-sealed-secret.yaml`
5. More info about this in [Secrets README](/secrets.md)

### 1.3 Wait for all pods in k3d to be Running / Completed

```sh
watch kubectl get pods -A
```

### 1.4 Access ArgoCD

```sh
kubectl -n argocd port-forward svc/argocd-server 8888:80
```

### 1.5 open a new terminal and set the `KUBECONFIG` environment variable

```sh
export KUBECONFIG=$(k3d kubeconfig write kubefirst)
```

### 1.6 copy the argocd root password to your clipboard

```sh
kubectl -n argocd get secret/argocd-initial-admin-secret -ojsonpath='{.data.password}' | base64 -D | pbcopy
```

### 1.7 login to argocd

[http://localhost:8888](http://localhost:8888)

- username: `admin`

- password: (paste from your clipboard)

## Step 2: Provisioning Cluster via GitOps in Civo/Vultr

- After `ArgoCD` is running, the following steps are handled declaratively via GitOps:

1. A `Workspace` resource in `registry/clusters/<name>/workspace.yaml` provisions a new cluster using `Terraform`.

2. A `wait.yaml` job ensures other components **wait until provisioning is complete.**

3. A `ProviderConfig` is applied for **credentials and backend** configuration.

4. The `Terraform` module is located at: `terraform/modules/<cloud>_cluster`

### To add or remove a cluster:

- Add/remove an `ArgoCD` Application YAML under `argo/clusters/`

- ArgoCD will:

1. Apply/Remove the Terraform `Workspace`

2. Create/Delete the `Kubernetes` cluster in `Civo/Vultr`

3. Register the new cluster in `ArgoCD` using a generated secret (resource `kubernetes_secret_v1.argocd_cluster_secret`)

## Clean up

### Delete mgmt-cluster

```bash
k3d node delete k3d-mgmt-cluster-agent-0 k3d-mgmt-cluster-server-0 k3d-mgmt-cluster-serverlb k3d-mgmt-cluster-tools
```
