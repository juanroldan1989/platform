# Civo Workload Cluster Provisioned via GitOps

This recording demonstrates how a Civo Kubernetes workload cluster is provisioned through the platform GitOps workflow.

## What the Video Shows

1. Argo CD detects the cluster overlay in `registry/clusters/overlays/frankfurt`.
2. The `provision-clusters` ApplicationSet generates the `provision-cluster-frankfurt` Argo CD Application.
3. The generated Application renders the Civo provisioning chart and creates a Crossplane Terraform `Workspace`.
4. The Terraform `Workspace` uses the shared `infra-modules` Civo cluster module to create the Kubernetes cluster in the Civo `FRA1` region.
5. The Civo dashboard shows the cluster creation process in real time.
6. The Argo CD UI shows the live sync and health status of `provision-cluster-frankfurt` while provisioning is in progress.
7. After the cluster is created, Argo CD reflects the successful state and the workload cluster is ready to be registered and managed by the platform.

## Key Outcome

The video highlights a fully automated provisioning flow: a cluster definition in Git is reconciled by Argo CD, executed through Crossplane and Terraform, and materialized as a running Civo Kubernetes workload cluster.
