# Failover scenarios (`Blog` app)

## Goals

- **Multi-cluster** Flaskr blog app distribution
- Stateful app architecture
- Automatic **cluster-level failover** with user transparency
- **Real-time data replication** / `backup-based` restore, to maintain state **across clusters**
- Cloud-native routing via `Cloudflare`
- `GitOps-compliant` deployment pipeline

## Initial state

2 `workload` clusters provisioned in `CIVO` cloud provider:

- `london`
- `frankfurt`

Both clusters run `workload` applications:

### `Blog` application

Traffic is load-balanced between these 2 clusters thanks to `Cloudflare GLB`.

## Failover at `cluster` level

- `london` cluster becomes unavailable.
- `100%` of traffic is routed to `frankfurt` cluster.
- Once the cluster is back up, traffic is re-routed back to `50/50` between `workload` clusters.
- We can simulate this scenario by removing `frankfurt` folder from `registry/clusters/overlays` folder.

## Failover at `application` level

- `Blog` replica application in `frankfurt` cluster becomes unavailable.
- `100%` of traffic is routed to `Blog` replica application in `london` cluster.
- We can simulate this scenario by removing `Blog` app from `frankfurt` cluster:

```yaml
# argo/apps/blog.yaml

...
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            cluster: "london"  # ArgoCD deploys app in "london" cluster only
            # workload: "true" # ArgoCD deploys app in "workload" clusters
...
```

- Steps work similar as with the `Hello World` app.
