# Observability Stack

This folder contains the shared GitOps configuration for the platform observability stack deployed to workload Kubernetes clusters.

The stack is designed to provide cluster, application, request, trace, and GPU visibility with minimal changes to application source code. Applications only need consistent Kubernetes metadata, such as labels, for the first version.

## Observability vs Monitoring

Monitoring answers whether a system is healthy by collecting known signals such as CPU, memory, network, pod health, and alerts.

Observability goes further. It helps explain why something is happening by combining metrics, traces, and service-level context. This makes it easier to understand request flow, latency, dependencies, and failures across the cluster.

This stack is called observability because it includes more than dashboards and resource metrics. It also adds tracing, telemetry routing, request discovery, and GPU visibility.

## Architecture

```text
Applications
  |
  | labels: observability/enabled=true
  v
Grafana Beyla
  |
  | eBPF request metrics and traces
  v
OpenTelemetry Collector
  |
  +--> Jaeger
  |      traces and request exploration
  |
  +--> Prometheus-compatible metrics
         scraped by kube-prometheus-stack

Kubernetes nodes, pods, services, and GPUs
  |
  +--> kube-state-metrics
  +--> node-exporter
  +--> NVIDIA DCGM exporter
  |
  v
Grafana dashboards
```

## Components Installed

### Grafana

Grafana provides dashboards for cluster and application visibility.

Typical views include:

- CPU and memory usage.
- Pod and namespace resource usage.
- Node health.
- Network and service metrics.
- GPU usage when GPU metrics are enabled.

Grafana is installed as part of the `kube-prometheus-stack` release.

### Prometheus-Compatible Metrics

The metrics stack is provided by `kube-prometheus-stack`.

It includes:

- Prometheus Operator.
- Prometheus.
- Alertmanager.
- kube-state-metrics.
- node-exporter.
- Grafana.

This gives the platform a standard Kubernetes metrics baseline for all workload clusters.

### OpenTelemetry Collector

The OpenTelemetry Collector receives telemetry from instrumented workloads and platform agents.

In this setup, it acts as the routing layer:

- Receives OTLP traces and metrics.
- Forwards traces to Jaeger.
- Exposes its own metrics for scraping.

Applications do not need to send telemetry directly to Jaeger. They can send telemetry to the Collector, and the Collector decides where it goes.

### Jaeger

Jaeger is used for trace exploration.

It helps answer questions such as:

- Which services handled a request?
- Where was time spent?
- Which component introduced latency?
- Did a request fail before or after reaching a specific service?

This setup currently uses in-memory storage, which is suitable for early platform validation but not long-term trace retention.

### Grafana Beyla

Grafana Beyla provides eBPF-based application auto-instrumentation.

It discovers pods labelled with:

```yaml
observability/enabled: "true"
```

Beyla can produce request metrics and basic traces without requiring application source code changes. This is useful for getting broad request visibility as more applications are added to the platform.

Reference:

```text
https://grafana.com/docs/beyla/latest/configure/service-discovery/#k8s-pod-labels
```

### NVIDIA DCGM Exporter

NVIDIA DCGM exporter exposes GPU metrics on GPU-enabled clusters.

It provides metrics such as:

- GPU utilization.
- GPU memory usage.
- Temperature.
- Power usage.
- GPU errors.

This component is deployed only to clusters labelled:

```yaml
gpu: "true"
```

## Access

The current configuration keeps observability services internal to the cluster. Access is available through `kubectl port-forward`.

### Grafana

```bash
kubectl -n observability port-forward svc/observability-metrics-grafana 3000:80
```

Open:

```text
http://localhost:3000
```

Default credentials are usually:

```text
username: admin
password: prom-operator
```

### Prometheus

```bash
kubectl -n observability port-forward svc/observability-metrics-prometheus 9090:9090
```

Open:

```text
http://localhost:9090
```

### Alertmanager

```bash
kubectl -n observability port-forward svc/observability-metrics-alertmanager 9093:9093
```

Open:

```text
http://localhost:9093
```

### Jaeger

```bash
kubectl -n observability port-forward svc/observability-jaeger 16686:16686
```

Open:

```text
http://localhost:16686
```

### OpenTelemetry Collector

The Collector does not provide a user interface. It exposes internal OTLP endpoints inside the cluster:

```text
observability-otel-collector.observability.svc.cluster.local:4317
observability-otel-collector.observability.svc.cluster.local:4318
```

Use port `4317` for OTLP gRPC and port `4318` for OTLP HTTP.

### Beyla

Beyla does not provide a user interface. Its metrics are scraped by Prometheus and visualized in Grafana.

### GPU Metrics

GPU metrics are scraped by Prometheus and visualized in Grafana. The exporter itself does not provide a user-facing dashboard.

GPU metrics are only expected on clusters with GPU nodes and the `gpu=true` cluster label.

## GitOps Deployment

The stack is deployed through Argo CD ApplicationSets under:

```text
argo/0-platform/observability
```

The base observability layer targets workload clusters:

```yaml
workload: "true"
```

GPU metrics target workload clusters with GPU support:

```yaml
workload: "true"
gpu: "true"
```

## Current Scope

The current version focuses on:

- Metrics.
- Dashboards.
- Traces.
- Request visibility through eBPF.
- GPU metrics for GPU clusters.

Logs and long-term trace storage are intentionally out of scope for the first version.

Ingress exposure for Grafana and Jaeger can be added as the next step when external access is required.
