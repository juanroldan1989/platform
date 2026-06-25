# Bootstrap `mgmt-cluster` in local machine

## Prerequisites

- k3d: local kubernetes
  - install: `brew install k3d`
- watch: repeat a command to watch resources
  - install: `brew install watch`
- kubectl: interact with kubernetes
  - install: `brew install kubectl`
- kubeseal: fetch the Sealed Secrets certificate and seal local secrets
  - install: `brew install kubeseal`
- yq: sanitize exported Kubernetes YAML before reusing it as bootstrap input
  - install: `brew install yq`
- civo account
  - set nameserver records at your domain registrar to `ns0.civo.com` and `ns1.civo.com`
  - add your domain in your [civo dns](https://dashboard.civo.com/dns)

# Clone `platform` repository

```sh
git clone https://github.com/juanroldan1989/platform
cd platform
```

# Step 1: Management Cluster

## 1.1 create a local bootstrap cluster

- We use `k3d` to provision `mgmt-cluster` that will need a `CIVO_TOKEN` added as a kubernetes secret.

- This `mgmt-cluster` will also have additional manifests that install `argocd` to the new cluster with a few default configurations.

### Creating `mgmt-cluster` for the first time:

1. Create cluster:

```sh
k3d cluster create mgmt-cluster \
  --agents "2" \
  --agents-memory "4096m" \
  --volume $PWD/bootstrap/mgmt-cluster.yaml:/var/lib/rancher/k3s/server/manifests/mgmt-cluster.yaml@server:0
```

2. Extract `public-key` associated with `Sealed Secrets`:

Run this after the `sealed-secrets-in-cluster` ArgoCD app has installed the controller in `kube-system`.

If the controller is not present yet, continue through the ArgoCD setup and cluster labeling steps below, wait for `sealed-secrets-in-cluster` to sync, then come back here.

```sh
./scripts/export-sealed-secrets-key.sh
```

This produces:

- `.sealed-secrets/mgmt/sealed-secrets-public.pem`: public certificate used by `scripts/seal-mgmt-secrets.sh`
- `.sealed-secrets/mgmt/sealed-secrets-key.yaml`: sanitized controller key Secret to re-use when recreating the management cluster

The private key manifest must be sanitized before reusing it with k3d/k3s. Do not export it with a raw `kubectl get secret ... -o yaml > file` command, because that keeps cluster-only fields such as `resourceVersion` and `uid`. K3s can reject that manifest during startup, causing the Sealed Secrets controller to generate a different key and making existing `SealedSecret` objects impossible to decrypt.

### Creating `mgmt-cluster` for future times:

1. Create cluster (include the existing `Sealed Secrets` key):

```sh
k3d cluster create mgmt-cluster \
  --agents "2" \
  --agents-memory "4096m" \
  --volume $PWD/bootstrap/mgmt-cluster.yaml:/var/lib/rancher/k3s/server/manifests/mgmt-cluster.yaml@server:0 \
  --volume $PWD/.sealed-secrets/mgmt/sealed-secrets-key.yaml:/var/lib/rancher/k3s/server/manifests/sealed-secrets-key.yaml@server:0
```

K3s auto-applies YAML files mounted into `/var/lib/rancher/k3s/server/manifests` on the server node.

Only the key Secret YAML needs to be mounted into the cluster. The public certificate stays on your host and is used by `scripts/seal-mgmt-secrets.sh` when creating sealed secrets.

After the controller starts, it should load this mounted key. If ArgoCD shows `no key could decrypt secret`, check [Secrets troubleshooting](/zdocs/secrets.md); the usual cause is that the mounted key was not applied or the `SealedSecret` was sealed with a different public certificate.

---

The result will be a **local bootstrap k3d cluster** with the necessary components **for app and infrastructure management**.

## 1.2 Cloud Provider API Tokens

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
3. Run the `./scripts/seal-mgmt-secrets.sh`
4. Commit changes made to `bootstrap/crossplane/0-crossplane-sealed-secret.yaml`
5. More info about this in [Secrets README](/zdocs/secrets.md)

## 1.3 Wait for all pods in k3d to be Running / Completed

```sh
watch kubectl get pods -A
```

## 1.4 Access ArgoCD

```sh
kubectl -n argocd port-forward svc/argocd-server 8888:80
```

## 1.5 open a new terminal and set the `KUBECONFIG` environment variable

```sh
export KUBECONFIG=$(k3d kubeconfig write kubefirst)
```

## 1.6 copy the argocd root password to your clipboard

```sh
kubectl -n argocd get secret/argocd-initial-admin-secret -ojsonpath='{.data.password}' | base64 -D | pbcopy
```

## 1.7 login to argocd

[http://localhost:8888](http://localhost:8888)

- username: `admin`

- password: (paste from your clipboard)

## 1.8 label mgmt-cluster properly

Create/update the ArgoCD cluster Secret for the management cluster:

```sh
kubectl apply -f argo/0-platform/argocd-support/argocd-in-cluster-secret.yaml
```

Or label the existing ArgoCD in-cluster Secret if it already exists:

```sh
kubectl -n argocd label secret cluster-in-cluster in-cluster=true --overwrite
```

This way, ArgoCD will provision all `ApplicationSet` apps meant to be provisioned in `mgmt-cluster`, e.g.: ingress-nginx, dns-config, sealed-secrets.

## 1.9 complete local-only setup

Run the local helper script to create the management-cluster AWS credentials used by ESO and the Terraform modules:

```sh
./scripts/bootstrap-mgmt-cluster-local.sh
```

The script reads AWS credentials from your local `default` AWS profile and creates `external-secrets/aws-creds`.

# Step 2: Provisioning Cluster via GitOps in Civo/Vultr

- After `ArgoCD` is running, the following steps are handled declaratively via GitOps:

1. A `Workspace` resource in `registry/clusters/workload/provision/<provider>/templates/workspace.yaml` provisions a new cluster using `Terraform`.

2. A `wait.yaml` job ensures other components **wait until provisioning is complete.**

3. A `ProviderConfig` is applied for **credentials and backend** configuration.

4. `Terraform` modules used by Workspace resources:

- `https://github.com/juanroldan1989/infra-modules.git//modules/civo/cluster`
- `https://github.com/juanroldan1989/infra-modules.git//modules/vultr/cluster`

## To add or remove a cluster:

- Add/Remove folder within `registry/clusters/overlays/*`

- Once committed and pushed, ArgoCD will:

1. Apply/Remove the Terraform `Workspace`

2. Create/Delete the `Kubernetes` cluster in `Civo/Vultr`

3. Register the new cluster in `ArgoCD` using a generated secret (resource `kubernetes_secret_v1.argocd_cluster_secret`)

# Step 3: Deploy applications in workload clusters

- Once `ArgoCD` has provisioned workload clusters, `argo/2-applications/app-of-apps.yaml` will take care of automatically deploying the applications into each cluster.
- Then, we access to a specific cluster, CIVO for example, and download the kubeconfig file and add it to Freelens.
- Then, we can validate applications are being deployed properly.
- Port-forward into a service and validate:

```
curl http://localhost:55907/

👋 Hello from frankfurt.automatalife.com
```

# Clean up

Do not delete the local `mgmt-cluster` first. The management cluster runs ArgoCD and Crossplane, so it must stay alive long enough to delete cloud resources through GitOps/Terraform. If you delete only the local k3d cluster, Civo/Vultr/Cloudflare resources can remain orphaned and continue consuming money.

## Automated cleanup

Run the cleanup script from the repository root:

```bash
./scripts/cleanup-mgmt-cluster-local.sh --confirm
```

The script deletes resources in this order:

1. Workload applications from workload clusters.
2. Cloudflare load balancer infrastructure.
3. Managed database infrastructure.
4. Workload Kubernetes clusters in Civo/Vultr.
5. The local k3d `mgmt-cluster`.

To remove cloud resources but keep the local management cluster running for inspection:

```bash
./scripts/cleanup-mgmt-cluster-local.sh --confirm --skip-k3d
```

## Manual cleanup order

`1-infrastructure` uses ArgoCD's resources finalizer. Deleting that Application is destructive: ArgoCD will cascade deletion to the infrastructure `ApplicationSet`s it manages, which can delete Crossplane Terraform `Workspace`s and destroy cloud resources.

If you prefer to do it manually, keep this order:

1. Delete `2-applications` so application workloads stop first.
2. Delete generated `hello-world-in-*` and `blog-in-*` Applications.
3. Confirm workload app PVCs/PVs and their cloud volumes are gone before deleting the workload cluster. For Civo, Kubernetes PVCs create Civo block volumes named `pvc-*`; if those volumes remain, Civo will refuse to delete the network.
4. Delete load balancer Applications: `provision-load-balancer-*`.
5. Wait until load balancer Terraform Workspaces are gone:

```bash
kubectl get workspaces
```

6. Delete database Applications: `database-for-*`.
7. Wait until `*-database-infrastructure` Workspaces are gone.
8. Delete workload cluster Applications: `provision-cluster-*`.
9. Wait until all cluster `*-infrastructure` Workspaces are gone.
10. **If a cluster Workspace gets stuck deleting its network**, check for leftover cloud volumes created by Kubernetes PVCs.

For Civo, a `DatabaseNetworkInUseByVolumes` error means the network still has volumes attached to it:

```bash
civo volume list --region FRA1
civo volume remove <volume-id> --region FRA1 --yes
```

11. Check the cloud provider dashboards for stale clusters, databases, load balancers, firewalls, volumes, and DNS records.
12. Delete the local management cluster:

```bash
k3d cluster delete mgmt-cluster
```
