# Two Paradigms of Platform Engineering

## Paradigm 1: GitOps-Direct (what this project implements)

The platform team manages both infrastructure definitions and app deployment templates in a single Git repo. The "contract" with app teams is **implicit** — if you want a database, add a folder to `registry/databases/overlays/`. If you want a new cluster, add a folder to `registry/clusters/overlays/`. Platform engineers control the entire surface.

```
App team → opens PR on platform repo → platform engineer merges → ArgoCD syncs
```

The infrastructure (Crossplane/Terraform Workspaces) and app templates (Helm charts) are authored and versioned together. They are **separately deployed** (mgmt cluster vs workload cluster, different sync waves), but they're **co-owned and co-authored** in the same repo, by the same team.

This is a completely valid and widely used approach. It is sometimes called **"Platform-as-Code"** or the **"Paved Road"** model.

---

## Paradigm 2: Internal Developer Platform (IDP) — Kratix / Humanitec

These tools add a **formal self-service API layer** between app teams and the platform. The key shift is that app teams no longer touch the platform repo at all. They express *what they need*, not *how to get it*.

```
App team → creates a CR or Score file in their own repo → IDP fulfills it automatically
```

The platform team defines the "what is possible". The IDP handles the "how".

---

## What This Project Would Look Like in Kratix

Kratix's core concept is the **Promise** — a contract written by the platform team that says "if you ask for X, I guarantee you'll get Y".

**Platform team writes (once):**
```yaml
# A Promise for a managed MySQL database
apiVersion: platform.kratix.io/v1alpha1
kind: Promise
metadata:
  name: mysql
spec:
  api:
    apiVersion: platform.example/v1
    kind: Database
    spec:
      properties:
        size: { type: string, enum: [small, medium, large] }
        region: { type: string }

  # What gets installed on worker clusters to support this
  workerClusterResources:
    - apiVersion: v1
      kind: Namespace
      metadata: { name: databases }

  # Pipeline that runs when someone requests a Database CR
  xaasRequestPipeline:
    - image: my-db-provisioner:latest  # runs your Terraform/Crossplane logic internally
```

**App team writes (in their own repo, no platform PR needed):**
```yaml
apiVersion: platform.example/v1
kind: Database
metadata:
  name: blog-db
spec:
  size: small
  region: lon1
```

Kratix sees the `Database` CR → runs the pipeline → provisions the CIVO database via Terraform → delivers credentials to the workload cluster. The app team never touches `registry/databases/overlays/`.

The Cloudflare LB, cluster provisioning, and ESO setup all become separate Promises. App teams compose them by creating CRs.

---

## What This Project Would Look Like in Humanitec

Humanitec's model centers on **Score** (an open workload spec) and **Resource Definitions**.

**App team writes `score.yaml` (in their app repo):**
```yaml
apiVersion: score.dev/v1b1
metadata:
  name: blog
containers:
  blog:
    image: ghost:5-alpine
    variables:
      database__client: mysql
      database__connection__host: ${resources.db.host}
      database__connection__user: ${resources.db.username}
      database__connection__password: ${resources.db.password}
      database__connection__database: ${resources.db.name}
resources:
  db:
    type: mysql
  dns:
    type: dns
```

The app team declares *what they need* (`mysql`, `dns`). They have zero knowledge of CIVO, Terraform, Crossplane, or AWS Secrets Manager.

**Platform team defines resource definitions (once, in Humanitec UI/API):**
- `mysql` → provision a CIVO managed DB via Terraform, inject credentials
- `dns` → create a Cloudflare DNS record
- `kubernetes` → deploy to a CIVO workload cluster

When the blog app is deployed to `london`, Humanitec's Platform Orchestrator resolves all dependencies, calls the right Terraform modules, injects the right environment variables, and wires it together. The connection between "blog needs mysql" and "CIVO managed DB in LON1" lives entirely in platform-team-controlled resource definitions.

---

## Comparison Table

| Dimension | GitOps-Direct (this project) | Kratix | Humanitec |
|---|---|---|---|
| **Self-service for app teams** | No — PR to platform repo required | Yes — submit a CR | Yes — push a Score file |
| **Coupling of infra + app** | Co-authored, separately deployed | Fully decoupled by API contract | Fully decoupled by Score spec |
| **Platform team overhead** | Low (just Git + ArgoCD) | High (Promise authoring, pipeline images, Kratix operator) | Medium–High (resource definitions, Humanitec operator or SaaS) |
| **Operational complexity** | Low | High | Medium (SaaS reduces ops burden) |
| **Multi-tenant support** | Manual (platform PR per team) | Built-in | Built-in |
| **Cost** | Free (OSS stack) | Free (OSS) | Commercial (Humanitec Platform Orchestrator) |
| **Auditability** | Git history | Git + Promise audit | Humanitec audit log |
| **Learning curve** | Low if you know ArgoCD + Helm | High (new concepts: Promises, pipelines) | Medium (Score is simple; resource defs are complex) |
| **Right for 1–2 engineers** | Yes | Overkill | Overkill |
| **Right for 5+ app teams** | Painful | Good fit | Good fit |

---

## The Coupling Debate — A Nuanced Take

The concern that "infrastructure and apps shouldn't be coupled" is really about **ownership**, not file proximity. In this project:

- The platform team owns both the Crossplane Workspace and the Ghost Deployment template.
- They deploy to different clusters at different times.
- The coupling is at the **authoring level**, not the runtime level.

This is fine as long as the platform team owns both sides. The coupling becomes a *real problem* when:

1. App teams want to provision their own infrastructure independently (self-service).
2. You have dozens of services and the platform team becomes a bottleneck for every new `registry/databases/overlays/` PR.
3. Infrastructure lifecycle (provision once, persist) and app lifecycle (deploy many times) diverge enough that tracking them together creates confusion.

For a current scale of one platform engineer and two apps, the coupling is a feature not a bug — full visibility over everything from one repo.

---

## When to Revisit Kratix or Humanitec

Don't migrate to Kratix or Humanitec prematurely. The operational overhead far exceeds the benefit at small scale. The trigger to revisit would be:

- You have **3+ independent app teams** who each want to provision their own resources without touching the platform repo.
- The platform repo becomes a **PR bottleneck** where you're merging 5+ "add my app" requests per week.
- You want to expose the platform as a **product** to other teams in an organization.

At that point, Kratix (open source, CNCF sandbox) is the more natural evolution from the current ArgoCD + Crossplane foundation because it **wraps** those tools inside Promises rather than replacing them.
