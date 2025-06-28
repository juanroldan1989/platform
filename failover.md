# Failover scenarios

## Initial state

2 `workload` clusters provisioned in `CIVO` cloud provider:

- `london`
- `frankfurt`

Both clusters run `workload` applications:

1. `Hello World` application: traffic is load-balanced between these 2 clusters thanks to `Cloudflare GLB`.

## Failover at `cluster` level

- `london` cluster becomes unavailable.
- `100%` of traffic is routed to `frankfurt` cluster.
- Once the cluster is back up, traffic is re-routed back to `50/50` between `workload` clusters.
- We can simulate this scenario by removing `frankfurt` folder from `registry/clusters/overlays` folder.

## Failover at `application` level

- `Hello World` replica application in `frankfurt` cluster becomes unavailable.
- `100%` of traffic is routed to `Hello World` replica application in `london` cluster.
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

---

1. `Hello World` application is removed from `frankfurt` cluster:

<img width="699" alt="Screenshot 2025-06-28 at 12 38 00" src="https://github.com/user-attachments/assets/12d3a684-6440-437b-a441-3e804dd3d602" />

<img width="758" alt="Screenshot 2025-06-28 at 11 46 04" src="https://github.com/user-attachments/assets/32106435-cf87-4b42-bcc0-bfe0dfc591fe" />

---

2. Cloudflare detects this endpoint is not available and marks its nodepool as `Unhealthy`:

<img width="600" alt="Screenshot 2025-06-28 at 11 45 00" src="https://github.com/user-attachments/assets/07c00377-121a-4d7b-83f2-91aae4be5496" />

---

3. Cloudflare also marks `Load Balancer` for `Hello World` application with `Health: Degraded`

<img width="1225" alt="Screenshot 2025-06-28 at 11 46 21" src="https://github.com/user-attachments/assets/c67751fd-931b-4ca5-8e5b-90d9a4886243" />

---

4. Future requests to https://hello.automatalife.com/ will be redirected to `Hello World` application in `london` cluster:

<img width="500" alt="Screenshot 2025-06-28 at 11 45 26" src="https://github.com/user-attachments/assets/dc4541fe-d446-49d4-8235-81fb2aca72fa" />

---

## More about Cloudflare GLB

[cloudflare-lb](/cloudflare-lb.md)
