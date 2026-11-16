# Next Steps: Central Secret Backend as Source of Truth

## Current Pattern

The current database credential flow is:

```
Crossplane Terraform Workspace
  -> Civo managed PostgreSQL database
  -> Kubernetes Secret in the management cluster
  -> ESO PushSecret
  -> AWS Secrets Manager
  -> ESO ExternalSecret in workload clusters
  -> local Kubernetes Secret consumed by the app
```

For the blog/wiki app, the management cluster currently creates:

```
blog-db/blog-db-managed-creds
```

That Secret contains:

```
username
password
host
port
database
connection_string
```

Then `PushSecret` publishes those values to AWS Secrets Manager:

```
civo/blog-database-credentials
```

Each workload cluster pulls the same values back into its own local Secret:

```
blog-db/blog-db-managed-creds
```

The application only knows about a normal in-cluster Kubernetes Secret. It does not know
about Civo, Terraform, Crossplane, AWS Secrets Manager, or ESO.

---

## Why This Is Good

**1. It proves the full GitOps credential lifecycle**

The platform can provision infrastructure, capture generated credentials, distribute them,
and consume them from a workload app without manual secret copy/paste.

**2. Workload clusters do not need direct access to Civo**

Only the management cluster needs the Civo token and Terraform provider. Workload clusters
only need AWS Secrets Manager read access through ESO.

**3. Apps consume a stable Kubernetes-native contract**

The app contract is simply:

```yaml
secretKeyRef:
  name: blog-db-managed-creds
```

This keeps application manifests portable and avoids provider-specific application config.

**4. AWS Secrets Manager becomes the cross-cluster distribution point**

Once the secret is pushed to AWS, any workload cluster can pull it independently. This is
much cleaner than copying Kubernetes Secrets between clusters.

**5. It is understandable for a small platform**

For a one-person platform or demo environment, this is easy to reason about:

```
provision DB -> create secret -> push secret -> app consumes secret
```

---

## Current Downsides

**1. The management-cluster Secret is doing too much**

`blog-db/blog-db-managed-creds` is both:

- the immediate output of database provisioning
- the source consumed by `PushSecret`
- shaped exactly like the workload app Secret

That makes it feel like the management-cluster Secret is the source of truth, even though
the better long-term source of truth is AWS Secrets Manager.

**2. Terraform knows about app namespaces**

The Terraform module creates a Kubernetes Secret in:

```yaml
namespace: blog-db
```

That couples infrastructure provisioning to an application namespace. If the app namespace
changes, the infrastructure module has to know.

**3. The handoff is spread across multiple controllers**

The lifecycle depends on several moving parts:

```
Terraform creates Kubernetes Secret
ESO PushSecret sees the Secret
AWS Secrets Manager receives the values
workload ESO pulls the values
app pod starts
```

This is fine, but debugging means checking Crossplane, the management Secret, PushSecret,
AWS Secrets Manager, the workload ExternalSecret, and the app pod.

**4. Secret naming is app-specific in shared infrastructure templates**

The current templates still contain blog-specific assumptions such as:

```
blog-db-managed-creds
civo/blog-database-credentials
```

This works for one app, but it does not scale cleanly to many databases or services.

**5. Rotation ownership is unclear**

If credentials rotate, it is not yet obvious which layer owns that rotation:

- Civo
- Terraform
- Crossplane
- the Kubernetes Secret
- AWS Secrets Manager
- ESO

The desired answer should be: the central secret backend owns the published secret contract.

---

## Improved Pattern

Make AWS Secrets Manager the canonical credential backend.

The improved flow should be:

```
Crossplane Terraform Workspace
  -> Civo managed PostgreSQL database
  -> AWS Secrets Manager secret
  -> ESO ExternalSecret in workload clusters
  -> local Kubernetes Secret consumed by the app
```

The management cluster still reconciles everything, but the management-cluster Kubernetes
Secret becomes either:

- a temporary implementation detail, or
- removed entirely if Terraform writes directly to AWS Secrets Manager.

The target source of truth is:

```
AWS Secrets Manager: civo/blog-database-credentials
```

not:

```
management cluster: blog-db/blog-db-managed-creds
```

---

## Recommended End State

### 1. Terraform writes DB credentials directly to AWS Secrets Manager

After Civo creates the database, Terraform should create or update an AWS Secrets Manager
secret containing the generated connection details.

Example target shape:

```json
{
  "username": "...",
  "password": "...",
  "host": "...",
  "port": "5432",
  "database": "blog_db",
  "connection_string": "postgresql://..."
}
```

This removes the need for `PushSecret` as the DB credential handoff mechanism.

### 2. Workload clusters only pull from AWS Secrets Manager

Each workload cluster keeps using ESO:

```
ExternalSecret -> AWS Secrets Manager -> blog-db-managed-creds
```

The app contract does not change.

### 3. Use stable, parameterized secret keys

Instead of hardcoding one global key:

```
civo/blog-database-credentials
```

use a predictable convention:

```
civo/{{ app }}-{{ environment }}-database-credentials
civo/{{ app }}-{{ region }}-database-credentials
```

Examples:

```
civo/blog-london-database-credentials
civo/blog-frankfurt-database-credentials
```

### 4. Keep app namespaces out of Terraform modules

Terraform should not need to know that the app namespace is `blog-db`.

Terraform should publish provider-neutral secret material to AWS Secrets Manager. Kubernetes
namespace placement should be handled by ESO manifests in the workload cluster.

### 5. Keep the management cluster as reconciler, not owner

The management cluster should continue to run:

- ArgoCD
- Crossplane
- Terraform provider
- ESO where needed

But the long-term credential owner should be AWS Secrets Manager.

---

## Migration Path

**Step 1: Parameterize the current secret names**

Replace hardcoded values like:

```
blog-db-managed-creds
civo/blog-database-credentials
```

with values-driven names.

**Step 2: Move PushSecret source to an infra namespace**

As an intermediate step, have Terraform write the generated Secret to a neutral namespace:

```
infra-secrets/blog-database-credentials
```

instead of:

```
blog-db/blog-db-managed-creds
```

This reduces app namespace coupling while keeping the current PushSecret pattern.

**Step 3: Add direct AWS Secrets Manager writes**

Extend the Terraform module to write the database credentials directly to AWS Secrets Manager.

At that point:

```
Terraform -> Kubernetes Secret -> PushSecret -> AWS SM
```

can become:

```
Terraform -> AWS SM
```

**Step 4: Remove DB PushSecret**

Once AWS Secrets Manager is populated directly by Terraform, remove the DB `PushSecret`.
Workload `ExternalSecret` resources continue to work as before.

**Step 5: Document ownership and rotation**

Document that:

- Civo owns the database instance.
- Terraform owns provisioning and secret publication.
- AWS Secrets Manager owns the credential record.
- ESO owns projection into workload clusters.
- Apps own only their local Secret reference.

---

## Summary

The current pattern is a good working bridge:

```
Terraform -> management Secret -> PushSecret -> AWS SM -> ExternalSecret -> app Secret
```

The improved production pattern is:

```
Terraform -> AWS SM -> ExternalSecret -> app Secret
```

The key design principle is:

**AWS Secrets Manager should be the canonical secret backend. Kubernetes Secrets should be
projections, not sources of truth.**
