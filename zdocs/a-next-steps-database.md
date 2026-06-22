# Option A: Regional Databases for True HA/DR

## The Problem

The current setup provisions a **single shared database in LON1** for all workload clusters:

```yaml
# registry/databases/overlays/blog/values.yaml (current)
name: civo-managed-db
region: LON1

database:
  name: ghost_blog_db
  size: g3.db.small
  version: "8.0"
  username: ghost
  nodes: 1
  target_namespace: blog-db
```

All three workload clusters connect to this one database:

```
london cluster    → LON1 database  ✅ same region (~2ms)
frankfurt cluster → LON1 database  ⚠️ cross-region (~20ms per query)
newyork cluster   → LON1 database  ⚠️ cross-Atlantic (~80ms per query)
```

This means:
- If the LON1 database goes down, **all clusters lose their data layer simultaneously**.
  Multi-region compute HA is nullified by single-region data.
- Frankfurt and New York users experience cross-region database latency on every page load.
- The ESO `PushSecret` pushes credentials to a single AWS SM key (`civo/blog-database-credentials`)
  that all clusters pull from — one set of credentials, one database, no isolation.

---

## The Fix: One Database Per Region

Provision one independent database per region. Each workload cluster connects exclusively
to the database in its own region. The Cloudflare Load Balancer handles failover at the
edge — if London goes down entirely (cluster + DB), traffic shifts to Frankfurt automatically.

```
london cluster    → LON1 database  ✅ local reads/writes
frankfurt cluster → FRA1 database  ✅ local reads/writes
newyork cluster   → EWR database   ✅ local reads/writes (when Vultr is enabled)
```

---

## What Changes in the Repository

### 1. One overlay folder per region (instead of one shared overlay)

**Current:**
```
registry/databases/overlays/
  blog/
    values.yaml    # LON1, shared by all clusters
```

**After:**
```
registry/databases/overlays/
  blog-london/
    values.yaml    # LON1
  blog-frankfurt/
    values.yaml    # FRA1
  blog-newyork/
    values.yaml    # EWR (when Vultr is ready)
```

The existing `argo/databases/blog.yaml` ApplicationSet already uses a git directory generator
scanning `registry/databases/overlays/*` — it will auto-discover all three folders with
zero changes to the ApplicationSet itself.

### 2. Per-region overlay values

```yaml
# registry/databases/overlays/blog-london/values.yaml
name: blog-london
region: LON1

database:
  name: ghost_blog_db
  size: g3.db.small
  version: "8.0"
  username: ghost
  nodes: 1
  target_namespace: blog-db
```

```yaml
# registry/databases/overlays/blog-frankfurt/values.yaml
name: blog-frankfurt
region: FRA1

database:
  name: ghost_blog_db
  size: g3.db.small
  version: "8.0"
  username: ghost
  nodes: 1
  target_namespace: blog-db
```

### 3. Per-region AWS Secrets Manager keys

The ESO `PushSecret` in `registry/databases/provision/templates/eso-push-secret.yaml`
currently hardcodes `civo/blog-database-credentials` as the remote key. With `{{ .Values.name }}`
templated properly, each regional database pushes to its own key:

```
civo/blog-london-database-credentials
civo/blog-frankfurt-database-credentials
civo/blog-newyork-database-credentials
```

This requires fixing the hardcoded `remoteKey` in `eso-push-secret.yaml`:

```yaml
# registry/databases/provision/templates/eso-push-secret.yaml (after fix)
data:
  - match:
      secretKey: username
      remoteRef:
        remoteKey: civo/{{ .Values.name }}-database-credentials   # was hardcoded
        property: username
  - match:
      secretKey: password
      remoteRef:
        remoteKey: civo/{{ .Values.name }}-database-credentials   # was hardcoded
        property: password
  - match:
      secretKey: host
      remoteRef:
        remoteKey: civo/{{ .Values.name }}-database-credentials   # was hardcoded
        property: host
  # ... etc
```

### 4. Per-cluster ExternalSecret pulling from the right regional key

The `ExternalSecret` deployed to each workload cluster (currently in
`registry/clusters/workload/secrets/blog-db-secret-sync.yaml`) needs to pull from the
correct regional key based on which cluster it's running in.

The cleanest way is to drive this from the cluster overlay values:

```yaml
# registry/clusters/overlays/london/values.yaml (addition)
database:
  secretsManagerKey: civo/blog-london-database-credentials

# registry/clusters/overlays/frankfurt/values.yaml (addition)
database:
  secretsManagerKey: civo/blog-frankfurt-database-credentials
```

The `ExternalSecret` template then references `{{ .Values.database.secretsManagerKey }}`
instead of the current hardcoded string.

---

## Ghost CMS and Multi-Region Data: What to Expect

Ghost does not support multi-primary replication. Each regional database is independent.
This means:

- A blog post published via the London admin panel exists **only in the LON1 database**.
  Frankfurt and New York readers see the same post only because the Cloudflare LB routes
  all traffic to whichever origin responds fastest — they're not reading from separate DBs.
- If you write to London and a reader hits Frankfurt, they get Frankfurt's DB state, which
  may be missing recently published content.

**This is acceptable for a blog CMS** where:
1. Publishing is rare (one author, occasional posts).
2. The Cloudflare LB uses health-check-based failover, not load distribution — so under
   normal conditions all traffic hits one origin (London), with Frankfurt as failover.
3. Content divergence only occurs during a real failure event, not during normal operation.

If true multi-region writes were needed, a globally replicated database (e.g., PlanetScale,
CockroachDB, or Neon with global branches) would be required — overkill for a blog.

---

## Migration Steps (Safe, No Downtime)

1. **Create the two new overlay folders** (`blog-london`, `blog-frankfurt`) with their
   `values.yaml` files. The existing `blog/` overlay stays in place — ArgoCD provisioning
   is additive, not destructive.

2. **Fix the `remoteKey` hardcoding** in `eso-push-secret.yaml` to use `{{ .Values.name }}`.

3. **Apply the ArgoCD sync** — two new databases are provisioned in parallel (LON1 and FRA1).
   Credentials are pushed to their respective AWS SM keys.

4. **Add `database.secretsManagerKey`** to each cluster overlay and update the
   `ExternalSecret` template to reference it.

5. **Migrate Ghost data** from the single shared DB to each regional DB. For a blog, a
   mysqldump + restore into each regional DB is sufficient.

6. **Verify** each workload cluster connects to its local DB, then **delete the old shared**
   `registry/databases/overlays/blog/` overlay to decommission the LON1-shared database.

---

## End State

```
registry/databases/overlays/
  blog-london/values.yaml    →  LON1 DB  →  AWS SM: civo/blog-london-database-credentials
  blog-frankfurt/values.yaml →  FRA1 DB  →  AWS SM: civo/blog-frankfurt-database-credentials

london workload cluster     →  ExternalSecret pulls civo/blog-london-database-credentials
frankfurt workload cluster  →  ExternalSecret pulls civo/blog-frankfurt-database-credentials
```

Cloudflare Load Balancer continues to monitor both origins. If London fails, Cloudflare
fails over to Frankfurt. The Frankfurt cluster serves content from its own local DB —
no cross-region dependency at runtime.
