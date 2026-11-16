# GitOps Scaling Options

A comparison of professional GitOps patterns to address the platform's current scaling issues,
particularly around adding new microservices and reducing file sprawl.

## The Problem Statement

Adding a two-service microservices system (`api` + `frontend`) under the current structure
requires **8–12 files/edits spread across 4 unrelated directory trees**. Infrastructure (DB, LB)
and application concerns have no linking concept.

---

## Option 1: Bundle Pattern

Co-locate app + infrastructure into one Helm umbrella chart. One `argo/bundles/{name}.yaml`
per system. Full details in `refactor-with-bundle.md`.

**Solves**: file sprawl, the 8–12 files-per-service problem.
**Doesn't solve**: the platform PR bottleneck if multiple independent app teams exist.

---

## Option 2: Multi-Repo Split (Platform Infra + App Config)

The most widely used professional pattern. Split the current monorepo into two distinct repos
along the ownership boundary:

```
platform-infra/              # Platform team owns this
  argo/
    tools/                   # cert-manager, ESO, ingress-nginx, external-dns
    clusters/                # provision + config ApplicationSets
    databases/               # DB provisioning ApplicationSets
    load_balancers/          # LB provisioning ApplicationSets
  registry/
    clusters/                # cluster Helm charts + overlays
    databases/               # DB Helm charts + overlays
    load_balancers/          # LB Helm charts + overlays

platform-apps/               # App teams (or separate platform sub-team) owns this
  argo/
    apps/                    # ApplicationSets per app
  registry/
    apps/                    # Helm charts per app
      blog/
      hello-world/
      commerce-api/
      commerce-frontend/
```

The `platform-infra` app-of-apps points at `platform-infra/argo/`, and a second app-of-apps
points at `platform-apps/argo/`:

```yaml
# In platform-infra — registers the apps repo into ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps-root
spec:
  source:
    repoURL: https://github.com/you/platform-apps.git
    path: argo
    directory:
      recurse: true
```

**Solves**:
- App teams can open PRs on `platform-apps` without touching infrastructure.
- Infrastructure changes don't pollute the same PR history as app deploys.
- Independent access controls: stricter reviews on `platform-infra`, lighter on `platform-apps`.

**Doesn't solve**: adding a new app still requires coordination between both repos (app config
in `platform-apps`, DB/LB provisioning in `platform-infra`).

**Fit for this project**: High. The `registry/apps/` and `argo/apps/` directories are already
cleanly separated from the infra side — this split follows the natural seam.

---

## Option 3: ApplicationSet Matrix Generator (Config-Driven Registration)

Instead of one YAML file per app, drive all deployments from a single central config file.
The ApplicationSet Matrix generator cross-products `clusters × apps`:

```yaml
# argo/apps/all-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps
spec:
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  workload: "true"
          - git:
              repoURL: https://github.com/you/platform.git
              revision: main
              files:
                - path: registry/apps/**/app.json   # one tiny file per app
  template:
    metadata:
      name: "{{app.name}}-in-{{name}}"
    spec:
      source:
        path: "registry/apps/{{app.name}}"
        helm:
          valueFiles:
            - $values/registry/clusters/overlays/{{name}}/values.yaml
```

Each app registers itself with a tiny `app.json`:

```json
// registry/apps/blog/app.json
{ "name": "blog", "syncWave": "70" }
```

```json
// registry/apps/commerce-api/app.json
{ "name": "commerce-api", "syncWave": "70" }
```

**Adding a new app** = create `registry/apps/commerce-api/` + drop in `app.json`. The
ApplicationSet auto-discovers it and deploys to every workload cluster. Zero new Argo YAML files.

**Solves**: eliminates the 1-YAML-per-app-per-ApplicationSet problem entirely.
**Doesn't solve**: the database/LB side still needs separate overlays.
**Fit for this project**: High for the app layer. The same pattern can extend to databases
with a `db.json` registration file per overlay.

---

## Option 4: Crossplane Compositions as Your Internal API

This option leans into Crossplane much harder. Instead of Helm charts for infrastructure,
define Composite Resource Definitions (XRDs) that bundle the entire provisioning pipeline
together at the Crossplane level:

```yaml
# A single CR is all you write to get a full DB + secret pipeline
apiVersion: platform.example.com/v1alpha1
kind: ManagedDatabase
metadata:
  name: blog-db
spec:
  region: lon1
  size: small
  appName: blog
  targetNamespace: blog-db
```

The platform team writes the `Composition` once — it internally creates the Crossplane
Workspace (Terraform), the ESO `PushSecret`, and any supporting resources. App teams or the
platform repo just instantiate `ManagedDatabase` CRs.

```
ManagedDatabase CR
  └── Composition
        ├── Workspace    (Terraform → CIVO DB)
        ├── PushSecret   (ESO → AWS Secrets Manager)
        └── ExternalSecret (AWS SM → workload cluster secret)
```

This directly eliminates the `eso-push-secret.yaml` hardcoding issue — the secret names and
remote key paths live inside the Composition template, parameterised by `spec.appName`.

**Solves**: hardcoded secret names, hardcoded region logic, the need for per-app overlay
folders in `registry/databases/`.
**Cost**: Composition authoring is complex. Debugging Compositions is harder than debugging Helm.
**Fit for this project**: Medium — powerful but requires significant rework of
`registry/databases/provision/`. Best introduced for new resources, not as a migration of existing ones.

---

## Option 5: Domain-based App-of-Apps Hierarchy

Instead of one flat `argo/` tree, introduce a two-level hierarchy that maps to ownership domains:

```
argo/
  app-of-apps.yaml             # root — registers the 3 domain roots below

  platform/
    app-of-apps.yaml           # DOMAIN: platform tools
    cert-manager.yaml
    eso.yaml
    ingress-nginx.yaml
    external-dns.yaml

  infrastructure/
    app-of-apps.yaml           # DOMAIN: provisioned resources
    clusters.yaml
    databases.yaml
    load-balancers.yaml

  applications/
    app-of-apps.yaml           # DOMAIN: application workloads
    blog.yaml
    hello-world.yaml
    commerce.yaml              # new suite lives here
```

Each domain root is its own ArgoCD `Application` pointing at its subdirectory. Sync waves are
scoped per-domain: platform tools sync first, infrastructure second, applications third —
enforced at the domain level, not via global wave numbers scattered across individual files.

**Solves**: discoverability, clear ownership boundaries, independent sync cycles per domain.
Platform tools can be synced without touching application config.
**Doesn't reduce file count** — this is about structure and clarity, not elimination of files.
**Fit for this project**: High and very low risk. This is a pure reorganisation of existing
files with no template changes required.

---

## Comparison Summary

| Option | Files to add new 2-service system | Infra/App coupling | Risk to existing setup | Effort |
|---|---|---|---|---|
| **Current** | 8–12 files | Scattered across 4 trees | — | — |
| **1. Bundle** | 1 dir + 1 Argo YAML | Co-located | Low | Medium |
| **2. Multi-repo split** | Same count, cleaner ownership | Separate repos | Low | Low |
| **3. Matrix generator** | 1 `app.json` per service | Unchanged | Low | Low |
| **4. Crossplane Compositions** | 1 CR per resource | Eliminated in Composition | Medium | High |
| **5. Domain hierarchy** | Same count, better discovery | Unchanged | Very low | Very low |

---

## Recommended Sequence

These options are not mutually exclusive. A practical adoption order:

1. **Option 5 first** — reorganise `argo/` into `platform/`, `infrastructure/`, `applications/`
   domains. Pure file moves, zero config changes, ArgoCD handles it transparently.

2. **Option 3 next** — replace per-app Argo YAMLs with a matrix-driven single ApplicationSet.
   Eliminates file sprawl for every new app going forward.

3. **Option 2 when a second contributor joins** — split repos once someone else needs to deploy
   apps without infrastructure access.

4. **Option 1 or 4** for new microservice suites — bundle for simplicity, Crossplane
   Compositions for maximum reusability and self-service.
