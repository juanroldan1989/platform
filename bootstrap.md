# Bootstrap

## Step 1: MGMT-Cluster

### 1.1 Command and Prerequisites

- k3d: local kubernetes
    - install: `brew install k3d`
- watch: repeat a command to watch resources
    - install: `brew install watch`
- kubectl: interact with kubernetes
    - install: `brew install kubectl`
- civo account
    - set nameserver records at your domain registrar to `ns0.civo.com` and `ns1.civo.com`
    - add your domain in your [civo dns](https://dashboard.civo.com/dns)

### 1.2 Clone `platform` repository
```sh
git clone https://github.com/juanroldan1989/platform
cd platform
```

### 1.3 create a local bootstrap cluster

- We use `k3d` to provision `mgmt-cluster` that will need a `CIVO_TOKEN` added as a kubernetes secret.

- This `mgmt-cluster` will also have additional manifests that install `argocd` to the new cluster with a few default configurations.

```sh
k3d cluster create kubefirst \
  --agents "1" \
  --agents-memory "4096m" \
  --volume $PWD/manifests/bootstrap-k3d.yaml:/var/lib/rancher/k3s/server/manifests/bootstrap-k3d.yaml
```

The result will be a local bootstrap k3d cluster with the necessary components for app and infrastructure management.

### 1.4 export your `CIVO_TOKEN` for provisioning cloud infrastructure

- Replace the x's with your actual API Key.

- It's available on your [profile security page](https://dashboard.civo.com/security) in your Civo account.

```sh
export CIVO_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

The `CIVO_TOKEN` will be used by the `crossplane terraform provider` to allow provisioning of:

1. CIVO cloud infrastructure
2. external-dns to create and adjust DNS records in your CIVO cloud account.

```sh
kubectl -n crossplane-system create secret generic crossplane-secrets \
  --from-literal=CIVO_TOKEN=$CIVO_TOKEN \
  --from-literal=TF_VAR_civo_token=$CIVO_TOKEN
```

### 1.5 wait for all pods in k3d to be Running / Completed

```sh
watch kubectl get pods -A
```

### 1.6 port-forward to argocd ui

```sh
kubectl -n argocd port-forward svc/argocd-server 8888:80
```

### 1.7 open a new terminal and set the `KUBECONFIG` environment variable

```sh
export KUBECONFIG=$(k3d kubeconfig write kubefirst)
```

### 1.8 copy the argocd root password to your clipboard

```sh
kubectl -n argocd get secret/argocd-initial-admin-secret -ojsonpath='{.data.password}' | base64 -D | pbcopy
```

### 1.9 login to argocd

[http://localhost:8888](http://localhost:8888)

- username: `admin`

- password: (paste from your clipboard)
