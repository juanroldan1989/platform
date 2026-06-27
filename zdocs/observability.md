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

Grafana will provide dashboards for cluster and application visibility, including CPU, memory, network, ingress traffic, and GPU metrics.

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
