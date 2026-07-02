# Observability Plan

This document describes the planned observability layer for the platform workload clusters.

## Goal

Provide monitoring and traceability for applications running across workload Kubernetes clusters with a low-intrusion, GitOps-managed approach.

The first version should avoid application source-code changes. Application teams should only need standard Kubernetes metadata, such as labels, so observability can scale as more applications are added.

## High-Level Architecture

```text
Applications
  |
  | request traffic, pod metrics, GPU metrics, traces
  v
OpenTelemetry Collector
  |
  +--> Prometheus-compatible metrics
  +--> Jaeger traces
  +--> Grafana dashboards
```

The observability stack will be managed as a platform add-on and deployed through Argo CD.

## Components

### Grafana

Grafana provides dashboards for cluster and application visibility, including CPU, memory, network, ingress traffic and GPU metrics.

<img width="947" height="896" alt="Screenshot 2026-06-28 at 13 18 52" src="https://github.com/user-attachments/assets/b69c9e26-97d0-48a4-a5aa-22c54d4f1b1e" />

#### Cluster And Node Health

Recommended dashboard: `Node Exporter / Nodes`

This screenshot shows node-level CPU, memory, disk, filesystem and network health:

<img width="1464" height="897" alt="Screenshot 2026-06-28 at 13 09 51" src="https://github.com/user-attachments/assets/c7abad9a-fc80-4680-a99d-a88259c35943" />


#### Application Resource Usage

Recommended dashboard: `Kubernetes / Compute Resources / Namespace / Pods`

This screenshot shows CPU and memory usage for application pods and namespaces:

<img width="1467" height="765" alt="Screenshot 2026-06-28 at 13 08 32" src="https://github.com/user-attachments/assets/5bcea876-3713-4e36-8cae-b409bea31ebe" />

<img width="1504" height="758" alt="Screenshot 2026-06-28 at 13 07 42" src="https://github.com/user-attachments/assets/aa3dad03-6a0f-42f6-9033-06fb6ad57e1f" />

### Prometheus-Compatible Metrics

Metrics collection will provide the standard operational view of each workload cluster:

- Node health and resource usage.
- Pod CPU and memory usage.
- Namespace-level resource usage.
- ingress-nginx traffic metrics.
- Application request metrics from eBPF instrumentation.

### OpenTelemetry Collector

The OpenTelemetry Collector will act as the telemetry routing layer. It will receive traces and metrics from instrumentation agents and forward them to the selected backends.

### Jaeger

Jaeger will provide trace exploration. It will help understand request paths, service dependencies, and latency across services.

### Grafana Beyla

Grafana Beyla will provide eBPF-based application auto-instrumentation. This gives baseline request visibility without adding tracing SDKs or agents inside the application containers.

This is useful for:

- RED metrics: rate, errors, and duration.
- Basic service maps.
- Request latency visibility.
- Broad coverage across many services with minimal changes.

Application-level OpenTelemetry SDKs can be added later only where deeper business spans are needed.

### NVIDIA DCGM Exporter

NVIDIA DCGM exporter will expose GPU metrics on GPU-enabled clusters. This will make GPU utilization, memory, temperature, power, and errors visible in Grafana.

GPU metrics will only be deployed to clusters labelled `gpu=true`.

#### Dashboard: `NVIDIA DCGM Exporter / GPU Metrics`

This screenshot shows GPU utilization, GPU memory usage, temperature and power usage while an AI workload is running.

<img width="1233" height="850" alt="Screenshot 2026-07-02 at 11 31 53" src="https://github.com/user-attachments/assets/3306f05d-8826-48a1-8a90-46be16869c03" />

## Rollout Strategy

Observability is introduced one layer at a time:

1. Create a GitOps-managed observability bootstrap layer.
2. Add the metrics stack.
3. Add GPU metrics for GPU clusters.
4. Add OpenTelemetry Collector.
5. Add Jaeger.
6. Add Beyla eBPF instrumentation.
7. Add standard labels to applications.
8. Expose Grafana and Jaeger through ingress.

## GitOps Model

The observability layer is deployed from `argo/0-platform` using Argo CD ApplicationSets.

The first bootstrap layer targets all workload clusters:

```yaml
matchLabels:
  workload: "true"
```

The shared configuration lives under:

```text
registry/clusters/workload/config/observability
```

## Non-Invasive v1

The first version does not require application source-code changes.

Applications may later receive standard labels such as:

```yaml
observability/enabled: "true"
app.kubernetes.io/name: <app-name>
app.kubernetes.io/component: <component-name>
```

These labels allow platform-level instrumentation to discover and group workloads consistently.

## Future App-Level Instrumentation

eBPF instrumentation provides a strong baseline, but it does not replace application-level spans for business-specific telemetry.

OpenTelemetry SDKs can be added later for details such as:

- Model selected by a user.
- Token generation timing.
- Database operation details.
- Business transaction names.
- Trace-to-log correlation.

The default approach remains: start broad and non-invasive, then add deeper instrumentation only where needed.
