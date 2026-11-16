# GitOps Platform Analysis & Bundle Refactor Plan

## Good Design Patterns

**1. App-of-Apps with recursive sync**
`argo/app-of-apps.yaml` points at the entire `argo/` tree and syncs recursively. Adding a new `ApplicationSet` to any subfolder is immediately picked up — zero bootstrapping friction.

**2. ApplicationSets with cluster label selectors**
All workload tools (`cert-manager`, `ingress-nginx`, `eso`, `external-dns`) use `clusters: selector: matchLabels: workload: "true"`. New workload clusters are adopted automatically just by labelling them.

**3. Git directory generator for overlays**
The pattern used in `argo/databases/blog.yaml`, `argo/load_balancers/provision.yaml`, and `argo/clusters/provision.yaml` — scanning `registry/*/overlays/*` — means adding a new database or LB only requires creating one folder with a `values.yaml`. That's genuinely scalable.

**4. Sync waves enforcing correct ordering**
Crossplane (wave 0) → Sealed Secrets (5) → cluster/DB provisioning (10) → Terraform Workspace (20) → ESO PushSecret (25) → ingress/ESO tooling (50–60) → apps (70). The sequencing is logical and intentional.

**5. Multi-cloud Helm subcharts**
`registry/clusters/workload/provision/Chart.yaml` uses Helm chart dependencies with conditions (`cloud_provider.civo.enabled`, `cloud_provider.vultr.enabled`). Overlays enable/disable providers — cloud-agnostic provisioning from a single chart.

**6. Secret flow: SealedSecrets → Crossplane → AWS SM → ESO**
The bootstrap secrets are sealed; Terraform pushes provisioned creds to AWS Secrets Manager via ESO `PushSecret`; workload ESO `ExternalSecret` pulls them. Clean, auditable secret lifecycle.

**7. Multi-source ApplicationSets**
Using `sources:` + `ref: values` to separate the chart source from the values source is a clean pattern that avoids baking environment config into the chart.

---

## Poor Design Patterns & Current Issues

**1. Blog app deploys into the wrong namespace**
The blog `ApplicationSet` sets `destination.namespace: blog-{{name}}`, but `registry/apps/blog/templates/blog.yaml` hardcodes `namespace: blog-db` on every resource (`Namespace`, `Deployment`, `Service`, `Ingress`, `PVC`). The app and its database share the same namespace. This creates a naming collision risk, unclear ownership, and makes independent lifecycle management impossible.

**2. Domain URL hardcoded in the Deployment**
```yaml
- name: url
  value: http://blog.automatalife.com   # not templated
```
This means every cluster (London, Frankfurt, New York) deploys Ghost pointing at the same hardcoded URL, ignoring `{{ .Values.global.name }}`. It breaks per-cluster routing. It should be `https://blog.{{ .Values.global.name }}.automatalife.com`.

**3. Two competing ExternalSecrets for the same DB credentials**
`registry/clusters/workload/secrets/blog-database-creds.yaml` pulls from `platform/databases/blog-db` with keys `mysql-username` / `mysql-password`.
`registry/clusters/workload/secrets/blog-db-secret-sync.yaml` pulls from `civo/blog-database-credentials` with keys `username` / `password`.
Both target namespace `blog-db` and both run on every cluster. One is dead code, and the key name mismatch (`mysql-username` vs `username`) means whichever the app references will silently fail on the other.

**4. `config-clusters` ApplicationSet ignores per-cluster values**
`argo/clusters/config.yaml` deploys `registry/clusters/workload/config` without any overlay-specific values, meaning `blog-db/values.yaml`, `eso/values.yaml`, `ingress-nginx/values.yaml` are identical across all clusters. You lose the ability to tune any of these per-region.

**5. `eso-push-secret.yaml` hardcodes the app name**
In `registry/databases/provision/templates/eso-push-secret.yaml`, the secret selector `name: blog-db-managed-creds` and all `remoteKey: civo/blog-database-credentials` paths are hardcoded. The `{{ .Values.name }}` is only used for the metadata name. Adding a second database would require copying this file and doing find/replace.

**6. Load Balancer workspace only supports exactly 2 regions**
`registry/load_balancers/provision/templates/workspace.yaml` has `london_pool_address` and `frankfurt_pool_address` as fixed Terraform vars. Adding a third region (New York, already in the overlays) requires modifying the Terraform module, the workspace template, AND every LB overlay. It doesn't scale.

**7. No resource requests/limits or health probes on any Deployment**
Neither `blog` nor `hello-world` Deployments have `resources:`, `readinessProbe:`, or `livenessProbe`. In a multi-cluster HA setup this means pods can be scheduled on under-resourced nodes and Kubernetes has no signal to restart them on failure.

**8. Known unresolved bug tracked as a TODO comment**
`argo/tools/external-dns-config.yaml` has a `TODO` at the bottom acknowledging that the dual generator (workload + in-cluster) causes `provision.yaml` to attempt creating a second in-cluster cluster. This is an actual defect in production, not just a note.

---

## The Core Scalability Problem: Adding Microservices

Here is exactly what you'd need to add today for a two-service system (`api` + `frontend`) that share a database:

| What | Files to create |
|---|---|
| App charts | `registry/apps/api/`, `registry/apps/frontend/` |
| Argo ApplicationSets | `argo/apps/api.yaml`, `argo/apps/frontend.yaml` |
| DB overlay | `registry/databases/overlays/api-suite/values.yaml` |
| DB Argo app | A new `argo/databases/api-suite.yaml` or modifying the existing one |
| LB overlay | `registry/load_balancers/overlays/api-suite/values.yaml` |
| Workload secrets | `registry/clusters/workload/secrets/api-db-creds.yaml` |
| Cluster overlay cert namespaces | Update every `overlays/{cluster}/values.yaml` cert_manager.wildcard.namespaces list |
| ESO secret store config | Potentially new ExternalSecret per namespace |

That's 8–12 files/edits for 2 services. The problem is that **infrastructure (DB, LB) and application concerns are split across unrelated directory trees with no linking concept**.

---

## Recommended Structural Improvement: The "Bundle" Pattern

Introduce a **bundle** as the unit of deployment. A bundle owns one or more microservices, all their infrastructure dependencies (DB, LB), and their secrets — grouped together.

### Proposed Directory Structure

```
registry/
  bundles/
    blog/                          # existing "blog" system
      Chart.yaml                   # umbrella Helm chart
      values.yaml                  # shared defaults
      subcharts/
        app/                       # Ghost app (moved from registry/apps/blog)
        db/                        # DB provisioning (moved from registry/databases)
        lb/                        # LB provisioning (moved from registry/load_balancers)
      overlays/
        london/values.yaml
        frankfurt/values.yaml
        newyork/values.yaml

    commerce/                      # NEW microservices suite
      Chart.yaml
      values.yaml
      subcharts/
        frontend/
        api/
        worker/
        db/                        # shared DB for all services
        lb/
      overlays/
        london/values.yaml
        frankfurt/values.yaml

argo/
  bundles/                         # replaces argo/apps, argo/databases, argo/load_balancers
    blog.yaml                      # ONE ApplicationSet → deploys entire blog bundle
    commerce.yaml                  # ONE ApplicationSet → deploys entire commerce suite
```

### What This Solves

- Adding `commerce` with 3 microservices requires: 1 bundle directory + 1 Argo YAML. Done.
- Infrastructure and apps move together. Deploying to a new region means adding one overlay, not touching 4 separate directory trees.
- Cert manager namespace list is driven by the bundle's own values, not scattered across cluster overlays.
- The `eso-push-secret.yaml` hardcoding issue disappears because `{{ .Values.name }}` comes from the bundle's values.

### Migration Path for Existing Apps

You don't need to migrate all at once. Keep the current `argo/apps/`, `argo/databases/`, `argo/load_balancers/` intact and introduce `argo/bundles/` alongside. New microservice systems use bundles. The blog migrates when convenient. ArgoCD will sync both trees in parallel with no conflict.

### One Immediate Tactical Win (Without Full Restructuring)

Introduce a `registry/apps/{app}/overlays/` pattern within the existing structure so the per-cluster `values.yaml` files live next to the app chart rather than in `registry/clusters/overlays/{cluster}/values.yaml`. This removes the need to touch cluster-level config when you add a new app — right now every new app forces you to update every cluster overlay to add its namespace to the cert-manager list.
