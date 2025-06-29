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

