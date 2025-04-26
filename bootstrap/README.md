# Bootstrap

## Provision MGMT Cluster

```bash
./bootstrap/bootstrap-mgmt-cluster.sh
```

## Provision Workload Clusters

```bash
./bootstrap/bootstrap-workload-clusters.sh
```

## Register Workload Clusters into MGMT Cluster

This way ArgoCD is able to connect to `workload` clusters (dev/test/prod) and deploy applications into them:

```bash
./bootstrap/register-workload-clusters.sh
```

## Deploying Applications into Workload Clusters

- Name App:

```bash
kubectl apply -f argocd-configuration/name-app-appset.yaml -n argocd
```
