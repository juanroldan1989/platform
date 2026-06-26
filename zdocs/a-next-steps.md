# Next Steps: Combining Domain Hierarchy + Bundle Pattern

Options 5 (Domain-based App-of-Apps) and 1 (Bundle) are complementary, not competing.
They target different parts of the repository and compose cleanly.

- **Option 5** restructures `argo/` — the ArgoCD application definitions.
- **Bundle pattern** restructures `registry/` — the Helm charts and values.

---

## Step 1: Apply Option 5 (Domain Hierarchy) — Completed

`argo/` has been reorganised into three ownership domains. This was a pure file move — no templates,
no values, no ArgoCD config changes required. ArgoCD handles it transparently because
`app-of-apps.yaml` still recurses the `argo/` tree.

```
argo/
  app-of-apps.yaml             # unchanged — recurses entire argo/ tree

  platform/                    # DOMAIN: platform-wide tooling
    app-of-apps.yaml
    cert-manager.yaml
    eso.yaml
    ingress-nginx.yaml
    external-dns.yaml
    sealed-secrets.yaml
    argocd-support/

  infrastructure/              # DOMAIN: provisioned shared resources
    app-of-apps.yaml
    clusters.yaml              # was: argo/clusters/provision.yaml
    databases.yaml             # was: argo/databases/blog.yaml
    load-balancers.yaml        # was: argo/load_balancers/provision.yaml

  applications/                # DOMAIN: application workloads
    app-of-apps.yaml
    blog.yaml                  # was: argo/apps/blog.yaml
    hello-world.yaml           # was: argo/apps/hello-world.yaml
```

**What this unlocks immediately:**
- Each domain has its own sync cycle — platform tools can be resynced without touching apps.
- Ownership is visible from the directory structure alone.
- New apps go into `applications/`, new shared infra goes into `infrastructure/`.

---

## Step 2: Apply Bundle Pattern — For All New Microservice Systems

Once the domain hierarchy is in place, new multi-service systems are created as bundles
under `registry/bundles/` and registered with a single YAML under `argo/applications/`.

```
registry/
  apps/                        # unchanged — blog and hello-world stay here
  bundles/
    commerce/                  # NEW: first microservices suite as a bundle
      Chart.yaml               # umbrella chart
      values.yaml              # shared defaults
      subcharts/
        frontend/              # service 1
        api/                   # service 2
        db/                    # DB provisioning (owns its own infrastructure)
        lb/                    # LB provisioning (owns its own infrastructure)
      overlays/
        london/values.yaml
        frankfurt/values.yaml

argo/
  applications/
    blog.yaml                  # unchanged
    hello-world.yaml           # unchanged
    commerce.yaml              # NEW: one ApplicationSet for the entire suite
```

Adding `commerce` requires: **1 bundle directory + 1 Argo YAML**. Done.

---

## The Key Philosophical Shift When Combining Both

Once a bundle owns its DB and LB, those per-app resources move from `argo/infrastructure/`
into `argo/applications/` (as part of the bundle's ApplicationSet).

The `infrastructure/` domain then becomes exclusively for **shared platform resources**:
- Cluster provisioning (affects all apps)
- Shared tooling config

Per-app infrastructure (database, load balancer) lives with the app bundle in `applications/`.
This is a cleaner separation than the current state where everything is mixed in flat `argo/` directories.

```
infrastructure/   →  shared platform resources (clusters, global config)
applications/     →  self-contained app bundles (app + its own DB + LB)
platform/         →  tooling installed on every cluster
```

---

## Migration Path for Existing Apps

No big-bang migration required:

1. **Option 5 completed** — files have been moved into `platform/`, `infrastructure/`,
   `applications/` domains. Blog and hello-world keep working without any template changes.

2. **Add new systems as bundles** — the next microservices suite goes straight into
   `registry/bundles/` and `argo/applications/`.

3. **Migrate blog to a bundle later** — when convenient, move `registry/apps/blog/` into
   `registry/bundles/blog/` with its DB and LB subcharts. Existing `argo/applications/blog.yaml`
   just gets its `path:` updated. No cluster changes, no secret changes.

---

## File Count Before and After

| Scenario | Current approach | After Option 5 + Bundle |
|---|---|---|
| Add new 2-service system | 8–12 files across 4 trees | 1 bundle dir + 1 Argo YAML |
| Add new region for existing app | Edit every cluster overlay | Add 1 overlay inside the bundle |
| Understand what deploys where | Read across `argo/apps`, `argo/databases`, `argo/load_balancers` | Open `argo/applications/` |
| Platform tools vs app changes | Mixed in same `argo/` flat list | Separate `platform/` and `applications/` domains |
