# Failover scenarios

2 `workload` clusters provisioned in `CIVO` cloud provider:

- `london`
- `frankfurt`

Running `workload` applications:

- `Hello World` application traffic is load-balanced between these 2 clusters thanks to `Cloudflare GLB`.

## Failover at `cluster` level

- `london` cluster becomes unavailable.
- Traffic is re-routed `100%` to `frankfurt` cluster.
- Once the cluster is back up, traffic is re-routed back to `50/50` between `workload` clusters.
- We can simulate this scenario by removing `frankfurt` folder from `registry/clusters/overlays` folder.

## Failover at `application` level

- `Hello World` replica application in `london` cluster becomes unavailable.
- Traffic is re-routed `100%` to `Hello World` replica application in `frankfurt` cluster.
- We can simulate this scenario by removing `Hello World` app from `frankfurt` cluster:

```yaml
# argo/apps/hello-world.yaml

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

- More info at [cloudflare-lb](/cloudflare-lb.md)
