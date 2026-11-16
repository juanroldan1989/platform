# Platform roadmap

Reviewed: 2026-11-16. All checklist items describe planned work; they do not claim
that the corresponding behavior is already implemented or validated.

## Purpose and scope

Develop this project as a reproducible platform reference implementation connecting
GitOps, infrastructure provisioning, application delivery, observability, GPU
workloads and recovery across cloud and bare-metal Kubernetes environments.

Extend toward developer self-service and governed ML environments through small,
measurable steps. A new controller, portal or repository split should solve a
demonstrated problem. GitOps remains compatible with a developer-facing API.

This roadmap consolidates the repository assessment and the document review below.
It adds no runtime configuration and does not automatically adopt older proposals.
See the [repository structure](repo-structure.md) for the current layout. Supporting
documents include historical walkthroughs and proposals; use them as background
and revalidate their examples against the current implementation.

## Milestones

| Order | Milestone | Completion evidence |
| --- | --- | --- |
| 1 | Accurate baseline and reproducible bootstrap | Fresh management cluster reaches one working workload |
| 2 | Maintained dependencies and repeatable releases | Tested compatibility matrix and repeatable image/module inputs |
| 3 | Automated component and scenario validation | Local lifecycle checks and explicit cloud validation status |
| 4 | Protected platform boundaries | Positive and negative access, admission and networking tests |
| 5 | Recovery and operational evidence | Measured restore, failover and management-plane recovery exercises |
| 6 | Small developer-facing contract | A second sample application onboards without editing platform internals |
| 7 | Optional ML tenancy integration | Isolation profiles verified using existing ML-lab work |
| 8 | EKS workload-cluster extension | The same workload contracts verified on actual EKS |

Use this dependency order to guide expansion. Fix known security and correctness
issues during the baseline work rather than waiting for their later milestone.

## 1. Establish the baseline and complete bootstrap

- [ ] Publish a capability matrix distinguishing configured, historically
  demonstrated, locally verified, cloud verified and planned behavior. Include
  provider, cluster profile, software versions, date and evidence.
- [ ] Reconcile documentation claims with actual implementation. Distinguish
  application traffic failover, database availability and data recovery.
- [ ] Document which bootstrap stages are manual and automate their readiness
  checks. The current bootstrap applies only the `0-platform` root; the
  `1-infrastructure` and `2-applications` roots exist separately, and the proposed
  overarching root in `argo/app-of-apps.yaml` is commented out.
- [ ] Retain the existing domain layout. Establish explicit resource ownership,
  dependency readiness and bounded waits across its roots.
- [ ] Fix disabled-overlay handling. The Hello World load-balancer directory is
  still selected by its generator although its values are commented out, causing
  a Helm render failure.
- [ ] Correct and validate the Hetzner provisioning path and its provider/settings.
  Record disabled Civo/Vultr profiles separately from verified provider support.
- [ ] Align application names, namespaces, health endpoints and database references.
  The current blog workload is Wiki.js with PostgreSQL; older Ghost/MySQL notes
  describe historical revisions.

Acceptance: from a fresh setup, one documented path creates a management cluster,
installs platform services, registers a workload cluster, deploys an application
and provides a reachable endpoint. Every required step and external prerequisite
is visible. Local management with cloud workers is labelled as cloud provisioning.

Related documents:

- [Local bootstrap](bootstrap/bootstrap-mgmt-cluster-local.md)
- [Remote bootstrap](bootstrap/bootstrap-mgmt-cluster-remote.md)
- [Civo integration](providers/civo.md)
- [Vultr integration](providers/vultr.md)

## 2. Maintain dependencies and make releases repeatable

- [ ] Migrate community Ingress NGINX to a maintained controller and evaluate
  Gateway API. Verify routing, TLS, DNS and application health during migration.
- [ ] Establish compatible versions of Kubernetes, Argo CD, Crossplane, its
  Terraform/OpenTofu integration, ESO and Helm charts. Plan controller upgrades
  separately from adopting a new provisioning abstraction.
- [ ] Pin infrastructure modules and application images to controlled release
  inputs. Document how updates are proposed, verified and rolled back.
- [ ] Add readiness/liveness/startup checks and resource budgets where appropriate.
  Include application-specific readiness rather than only process availability.
- [ ] Document required storage classes, GPU runtime prerequisites and the
  differences between CPU-only and GPU-enabled profiles.

Acceptance: a recorded release can be reproduced and its application version
identified. Dependency upgrades have a tested compatibility and rollback path.

Related documents:

- [DNS and HTTPS configuration](networking/dns.md)
- [Cloudflare load balancing](networking/cloudflare-lb.md)
- [Canary deployment proposal](proposals/a-next-steps-canary-deployments.md)

The canary proposal assumes the existing ingress controller; revalidate its traffic
routing integration when choosing a maintained replacement.

## 3. Automate validation in layers

- [ ] Run Helm rendering, schema/input validation, shell checks and relevant
  Terraform checks in CI, including enabled and intentionally disabled profiles.
- [ ] Add component fixtures for cluster registration, application rendering,
  secret delivery, load-balancer configuration and database wiring.
- [ ] Use local Kubernetes clusters for Argo CD reconciliation and application
  integration tests. Floci may support the AWS Secrets Manager portion; it does
  not establish compatibility with Civo, Vultr or Hetzner provisioning.
- [ ] Test the scenario lifecycle: bootstrap, register a workload cluster, deploy
  release A, observe it, deploy release B, verify B, check convergence, remove the
  disposable scenario and verify cleanup.
- [ ] Test expected failures: invalid registration, missing dependencies, disabled
  overlays, rejected policy violations and unavailable secret backends.
- [ ] Keep local and cloud paths based on shared components and application
  assertions, with explicit environment configuration and separate state.
- [ ] Verify actual cloud behavior in temporary environments before marking each
  provider/profile as cloud validated. Rendering alone is insufficient evidence.

Acceptance: CI produces results tied to a revision and environment. Cleanup checks
resource existence, not only an empty state or the disappearance of an Argo app.
GPU execution and cloud-specific checks retain separate validation status.

Related documents:

- [Civo GitOps provisioning recording](providers/civo-workload-cluster-provisioned-via-gitops.md)
- [DNS troubleshooting](networking/dns.md)
- [Secret troubleshooting](operations/secrets.md)

## 4. Protect platform boundaries

- [ ] Define who controls platform services, workload clusters, application
  namespaces, infrastructure provisioning, secrets and GPU allocation.
- [ ] Replace unrestricted application access with scoped Argo CD projects,
  repository permissions and appropriately separated service accounts.
- [ ] Add native resource and pod-security controls plus network policies enforced
  by the selected CNI. Verify required DNS, API, telemetry and model traffic.
- [ ] Test denied lateral access, forbidden workloads and over-budget allocations.
- [ ] Parameterize secret names and paths, separate provisioning credentials from
  application credentials, and verify rotation through application adoption.
- [ ] Choose one reconciler to own each policy/control object. If Kyverno generates
  native controls, Argo CD owns its policy definitions, not the same generated
  objects. Add Kyverno when validation/generation requirements justify it.
- [ ] Make onboarding wait for mandatory controls before granting tenant access.

Acceptance: an application or tenant user can perform intended tasks but cannot
alter the authoritative controls or obtain unrelated credentials. Tests establish
enforcement; labels and configuration declarations alone do not establish it.

Related documents:

- [Security assessment](operations/security.md)
- [Secret management](operations/secrets.md)
- [Central secret backend proposal](proposals/a-next-steps-central-secret-backend.md)

## 5. Demonstrate recovery and operational behavior

- [ ] Test application-origin failure separately from database and regional failure.
  The current shared single-node London database remains a common dependency.
- [ ] Restore a database backup into a disposable recovery environment; record
  recovery time, data loss and application verification.
- [ ] Recover the management plane with its Terraform state, registration material
  and secret-decryption keys. Git manifests alone do not recover that state.
- [ ] Define retention and deletion rules for databases, state, secrets and volumes.
  Verify that removing an application release does not unintentionally destroy
  persistent data or shared dependencies.
- [ ] Exercise provisioning failure, interrupted cleanup and resource adoption or
  recovery. Preserve controller availability until required cloud teardown ends.
- [ ] Use telemetry to diagnose an injected application failure, with an actionable
  alert and runbook. Document the current retention and persistence limits.
- [ ] Record cost assumptions and measured operating results; distinguish declared
  resource quotas, observed usage and actual financial budgets.

Acceptance: publish small reproducible exercises with expected results, observed
results and limitations. Record measured onboarding, deployment, recovery and
cleanup behavior.

Related documents:

- [Data management](operations/data.md)
- [Hello World failover](operations/failover-hello-world.md)
- [Blog failover](operations/failover-blog.md)
- [Observability](operations/observability.md)
- [Regional database proposal](proposals/a-next-steps-database.md)

## 6. Introduce a developer-facing contract

- [ ] Measure the current onboarding process for a second sample service: files
  edited, required privileges, manual handoffs and time to a healthy endpoint.
- [ ] Define a validated application/system descriptor covering ownership,
  namespace, image, target profile, health, resource budget and dependency references.
- [ ] Generate workload Applications only for compatible target clusters. Preserve
  GPU and other eligibility selectors rather than deploying every app everywhere.
- [ ] Use config-driven ApplicationSet generation where it reduces duplication.
  Validate its parameter names, values sources and disabled-entry behavior.
- [ ] Introduce logical bundles for a small multi-service system if they improve
  onboarding. Keep management-cluster infrastructure and workload-cluster apps as
  separate Applications with explicit readiness and connection contracts.
- [ ] Define shared versus per-region database/LB ownership. Do not duplicate a
  shared database merely because an application deploys into another region.
- [ ] Migrate ownership in a disposable environment first. Test pruning,
  finalizers, retention and recovery before moving an existing resource.
- [ ] Compare the new onboarding process with the baseline. Confirm that a second
  application uses the interface without hardcoded names or platform-template edits.

Acceptance: the descriptor reduces developer knowledge and privileges while
preserving explicit infrastructure lifecycles. A bundle groups a system's intent;
it does not require every resource to share a destination or deletion lifecycle.

Related documents:

- [Platform paradigms](architecture/2-paradigms.md)
- [Scaling options](architecture/a-current-scaling-problem-and-scaling-options.md)
- [Bundle refactor](architecture/a-next-steps-refactor-with-bundle.md)
- [Combined hierarchy/bundle proposal](proposals/a-next-steps.md)

### Optional abstraction decisions

- Evaluate a Crossplane `ManagedDatabase` API only if the descriptor leaves a
  repeated provisioning/credential workflow that benefits from reconciliation.
- Split app and infrastructure repositories when ownership/review requirements
  justify it; file separation alone does not provide self-service or isolation.
- Evaluate Kratix or a Score-based workflow against one proven contract before
  selecting a broader IDP layer. They can complement GitOps.
- Decide using onboarding friction, required permissions, lifecycle behavior and
  maintenance cost. Team-count thresholds in older notes are heuristics.

## 7. Extend toward governed ML tenancy when the baseline is proven

- [ ] Reuse and reference the existing ML-lab templates, native guardrails, Kyverno
  generation examples and GitOps ownership patterns. Parameterize them for this
  platform rather than maintaining copies with divergent behavior.
- [ ] Distinguish a workload cluster, a shared-node vCluster tenant and a
  private-node tenant. Document who administers each API and worker environment.
- [ ] For shared-node tenants, enforce mandatory restrictions on translated host
  objects outside tenant control; constrain sync permissions and selector metadata.
- [ ] For private-node tenants, place workload admission, networking and resource
  enforcement in the actual worker environment or protected infrastructure layer.
  Host-cluster admission does not see those private-worker Pods through sync.
- [ ] Define an approved model-access path per profile. Private-node tenants need
  a reachable authenticated gateway/network path rather than service replication.
- [ ] Test two tenants: approved model access succeeds, unrelated tenant/host access
  fails, allocation limits hold and template/policy changes require platform rights.
- [ ] Separate cheap CPU-only control tests from GPU runtime and performance tests.
  Add runtime detection, image verification and cost reporting to address measured
  gaps after the initial boundaries are demonstrated.

Acceptance: tenant-admin capabilities and isolation limits are explicit, with
positive and negative tests for each supported node model. Protect provisioning
configuration as well as policies; a tenant must not be able to remove its boundary.

Related documents:

- [Security assessment](operations/security.md)
- [Secret management](operations/secrets.md)
- [GPU observability notes](operations/observability.md)

## 8. Add an EKS workload-cluster path

- [ ] Add EKS provisioning or onboarding once the common cluster contract is stable.
- [ ] Reuse application, health, observability and recovery contracts while keeping
  AWS IAM, networking, storage and GPU prerequisites explicit.
- [ ] Run actual AWS integration checks and record their cost and cleanup results.
- [ ] Compare operational responsibilities across EKS, other workload clusters and
  bare-metal Kubernetes. Keep ECS implementation in its complementary project.

Related documents:

- [Cluster integration pattern](providers/civo.md)
- [DNS and HTTPS configuration](networking/dns.md)
- [Observability](operations/observability.md)

## Review of the expansion documents

### Two paradigms of platform engineering

Source: [2-paradigms.md](architecture/2-paradigms.md).

The ownership/API-contract discussion is useful. Revise the binary framing:
GitOps is a delivery/reconciliation model, and an IDP is a developer-facing product
with contracts and workflows. Self-service can begin with validated Git requests
and delegated permissions. Adopting Kratix or Humanitec is not required to become
an IDP, and neither automatically provides the complete isolation model.

The Kratix snippet is historical: current Promise authoring uses an API CRD,
`dependencies` and `workflows` with resource configure/delete pipelines. Score is
an independent workload specification with multiple implementations, not a
Humanitec-only interface. Treat the examples as conceptual until validated against
pinned tool versions. Avoid unsupported cost/complexity rankings and fixed team
counts as adoption rules.

### Scaling problem and options

Source: [a-current-scaling-problem-and-scaling-options.md](architecture/a-current-scaling-problem-and-scaling-options.md).

Config-driven registration and ownership boundaries are useful near-term ideas.
The domain directories already exist, so complete bootstrap/readiness instead of
repeating the proposed reorganization. Cross-Application readiness is not provided
by global wave numbers alone; account for child health and dependency readiness.

The matrix example is a sketch: its flat JSON does not match the `app.name`
reference, and its `$values` use needs a corresponding source reference. Validate
the actual generator/template and application eligibility before replacing working
ApplicationSets. Repository splits and Crossplane APIs remain conditional options.
Measure the stated file-count reduction rather than assuming it.

### ML-lab next steps

Source: [ML-lab next steps](https://github.com/juanroldan1989/vcluster/blob/main/ml-lab/next-steps.md).

The central principle is sound: tenant-admin-editable defaults do not establish an
enforcement boundary. Its scope must distinguish shared-node sync from private
workers. CNI enforcement, permitted sync features, admission and trusted selectors
need verification. In the same repository, `step-6.guardrails` already provides
native, Kyverno and GitOps examples with more precise scope/ownership notes; use
those as implementation references rather than treating all next steps as absent.

### Bundle refactor

Source: [a-next-steps-refactor-with-bundle.md](architecture/a-next-steps-refactor-with-bundle.md).

Logical grouping is useful, but one ordinary Argo CD Application has one cluster
destination. A single umbrella chart does not itself deploy provisioning resources
to the management cluster and application resources to workload clusters. Use a
parent composition that generates separate Applications and preserves ownership.

Retain database/state lifecycles independently of application releases. Parallel
old/new layouts are safe only when they do not reconcile the same resources;
pruning and finalizers make ownership migration consequential. Helm dependencies
must be declared and built into `charts/`; `subcharts/` is not auto-discovered.

Some listed defects describe old revisions: the blog implementation has changed,
the duplicate ExternalSecret file is absent, the root layout has changed and the
AI workload now has health probes. Hardcoded database secret paths and fixed
London/Frankfurt LB pools remain relevant concerns. Revalidate each defect before
creating implementation tasks.

## Reference material

- [Argo CD resource health and child Application readiness](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)
- [Argo CD sync phases and waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [ApplicationSet pruning and resource deletion](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Application-Deletion/)
- [Helm chart dependencies](https://helm.sh/docs/topics/charts/)
- [Kratix Promise reference](https://docs.kratix.io/main/reference/promises/intro)
- [Score specification and implementations](https://docs.score.dev/docs/)
- [vCluster security boundaries](https://www.vcluster.com/docs/vcluster/security/)
- [vCluster private-node configuration and limitations](https://www.vcluster.com/docs/vcluster/configure/vcluster-yaml/private-nodes/)
- [Existing ML-lab guardrail examples](https://github.com/juanroldan1989/vcluster/tree/main/ml-lab/2.vcluster-platform/step-6.guardrails)
