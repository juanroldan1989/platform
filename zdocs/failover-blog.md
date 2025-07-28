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

Traffic is load-balanced between these 2 clusters thanks to `Cloudflare GLB`:

<img width="1321" alt="Screenshot 2025-07-05 at 09 47 35" src="https://github.com/user-attachments/assets/0332a06b-3045-4b9f-ad8c-fd29a1422f27" />

## Cloudflare setup

<img width="1020" alt="Screenshot 2025-07-05 at 09 50 46" src="https://github.com/user-attachments/assets/57292537-c510-4357-9320-c73aae244b3c" />
<img width="859" alt="Screenshot 2025-07-05 at 09 51 23" src="https://github.com/user-attachments/assets/2da55bd0-9e4f-4971-847d-fccaedb7351c" />
<img width="871" alt="Screenshot 2025-07-05 at 09 51 50" src="https://github.com/user-attachments/assets/d06f8ea5-a2a2-4a82-9ef3-b3e411896198" />

### Domains

1. Requests to https://blog.automatalife.com/ will be redirected to `Blog` application between `london` and `frankfurt` clusters.

<img width="823" alt="Screenshot 2025-07-05 at 09 56 22" src="https://github.com/user-attachments/assets/43ef160b-8456-4206-a908-0870253ef420" />

- The whole purpose is to provide an experience completely **transparent** for the end users.
- Users **should not be aware** in which cluster (or cloud provider) the `Blog` application is running.

- Each individual app are also accessible for testing purposes:

<img width="819" alt="Screenshot 2025-07-05 at 09 56 46" src="https://github.com/user-attachments/assets/01b45010-2a99-43fd-99b2-168500314d46" />
<img width="822" alt="Screenshot 2025-07-05 at 09 56 57" src="https://github.com/user-attachments/assets/6a260800-61f6-45a1-9c4e-80509bbb0047" />

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

## Data synchronization

- Currently each `Blog` app is running on separate clusters **with separate databases**.
- One of the goals of this "platform" project is to provision a mechanism in which:

1. Data is kept in sync **across clusters**
2. Data is kept in sync **across cloud providers**
3. Data availability experience is completely transparent for a User accessing their acccount and posts across regions.

- Implementation phases can be found [here](/data.md)
