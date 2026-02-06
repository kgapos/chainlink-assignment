# Designing an End-to-End Observability Pipeline (Local)

## Goal
Design and document a complete local observability pipeline that ingests and stores metrics, logs, and traces from a VeChain node. The system runs entirely on a local Kubernetes cluster, receives OTLP telemetry, and persists data via PersistentVolumes.

## Architecture Overview
Local Kubernetes distribution: `kind` (Kubernetes-in-Docker) with `local-path` storage class.

Core components:
- **OpenTelemetry Collector** (gateway): OTLP ingestion, processing, routing.
- **Metrics**: Prometheus (scrape + TSDB storage).
- **Logs**: Loki (log store) + Promtail (agent) or OTel Collector log receiver.
- **Traces**: Tempo (trace store).
- **Visualization**: Grafana.

Signal ingress:
- **OTLP gRPC/HTTP** from the VeChain node to the OTel Collector gateway.
- **Prometheus pull** for metrics scraping (VeChain node exposes `/metrics` when enabled).

Persistence:
- Prometheus TSDB -> PV
- Loki chunks + index -> PV
- Tempo blocks + WAL -> PV
- Grafana dashboards -> PV

## Logical Pipelines

### Metrics Pipeline
1. VeChain node exposes `/metrics` (Prometheus format).
2. Prometheus scrapes targets discovered via Kubernetes service discovery.
3. Prometheus stores metrics in local PV-backed TSDB.
4. OTel Collector can also accept OTLP metrics and remote_write to Prometheus (optional).

### Logs Pipeline
1. VeChain node emits stdout/stderr to container logs.
2. Promtail tails container logs and forwards to Loki.
3. Loki stores logs locally with PV-backed chunks and index.

### Traces Pipeline
1. VeChain node (or a small wrapper process) sends OTLP traces.
2. OTel Collector receives, batches, and forwards to Tempo.
3. Tempo stores traces in PV-backed blocks with WAL.

## Dataflow Diagrams

### Context Diagram
```
                +---------------------------+
                |        VeChain Node       |
                |  (metrics/logs/traces)    |
                +-------------+-------------+
                              |
                 OTLP gRPC/HTTP|   /metrics
                              |       |
                              v       v
                   +-----------------------+
                   | OpenTelemetry         |
                   | Collector (gateway)   |
                   +-----------+-----------+
                               |
               +---------------+-----------------+
               |                                 |
               v                                 v
        +-------------+                    +-------------+
        |   Tempo     |                    | Prometheus  |
        | (traces)    |                    | (metrics)   |
        +------+------+                    +------+------+  
               |                                 |
               v                                 v
        PV-backed storage                  PV-backed TSDB

                    +----------------+
                    |     Loki       |
  Promtail -------->|    (logs)      |
                    +-------+--------+
                            |
                            v
                     PV-backed storage

                +----------------------+
                |      Grafana         |
                |  Dashboards/Explore  |
                +----------+-----------+
                           |
                           v
                   PV-backed storage
```

### Sequence Diagram (OTLP Traces)
```
VeChain Node -> OTel Collector: OTLP trace spans
OTel Collector -> OTel Collector: batch/attributes sampling
OTel Collector -> Tempo: OTLP export
Tempo -> PV: write WAL + blocks
Grafana -> Tempo: query trace by trace_id
```

### Sequence Diagram (Prometheus Metrics)
```
Prometheus -> VeChain Node: GET /metrics
VeChain Node -> Prometheus: Prometheus text exposition
Prometheus -> PV: append TSDB blocks
Grafana -> Prometheus: query metrics (PromQL)
```

### Sequence Diagram (Logs)
```
VeChain Node -> Container runtime: stdout/stderr
Promtail -> Container runtime: tail logs
Promtail -> Loki: push batches
Loki -> PV: store chunks + index
Grafana -> Loki: query logs (LogQL)
```

## Local Kubernetes Stack

Recommended versions (example):
- Kubernetes: `kind v0.22+`
- OpenTelemetry Collector: `otel/opentelemetry-collector-contrib`
- Prometheus: `prom/prometheus`
- Loki: `grafana/loki`
- Tempo: `grafana/tempo`
- Grafana: `grafana/grafana`

Key services (namespaces suggested):
- `observability`: otel-collector, prometheus, loki, tempo, grafana, promtail
- `apps`: vechain node with OTLP + /metrics

## Storage & Persistence

Use a `StorageClass` backed by `local-path` (default in kind) and create
PVCs for Prometheus, Loki, Tempo, and Grafana.

Persistence plan:
- Prometheus: TSDB data
- Loki: chunks + index
- Tempo: WAL + blocks
- Grafana: dashboards and sqlite

## OTLP Ingestion

OTel Collector gateway with receivers:
- `otlp` (gRPC + HTTP)

Exporters:
- `otlp` to Tempo
- `prometheusremotewrite` (optional; if using OTLP metrics)
- `loki` (optional; if using OTel logs)

Processors:
- `batch`, `memory_limiter`, `attributes` (for standard metadata)

## Basic Operability Signals

Minimum internal observability:
- **Health checks**: readiness/liveness probes for all services.
- **Dashboards**: Grafana dashboards for Prometheus, Loki, Tempo, OTel Collector.
- **Alerts**: Prometheus rules for high error rates, scrape failures, and component restarts.
- **Service logs**: query Loki for component logs.

Suggested alerts:
- Prometheus `up == 0` for core services.
- OTel Collector queue length + dropped spans.
- Loki write errors, Tempo ingest errors.

## Reliability & Operability Practices

- Use resource requests/limits to avoid noisy neighbor issues.
- Use `PodDisruptionBudget` for core services (single-node friendly).
- Add `PodSecurityContext` and run as non-root where possible.
- Keep configuration in ConfigMaps with versioned values.

## Optional Proof-of-Concept (Bonus)

Example demo app:
- `vechain-node` deployment configured to emit OTLP traces and expose `/metrics`.

Example configuration layout:
- `k8s/otel-collector.yaml`
- `k8s/prometheus.yaml`
- `k8s/loki.yaml`
- `k8s/tempo.yaml`
- `k8s/grafana.yaml`
- `k8s/vechain-node.yaml`

## Validation Checklist

- `kubectl get pods -n observability` shows all pods ready.
- Grafana connects to Prometheus, Loki, and Tempo.
- Metrics visible in Prometheus and Grafana.
- Logs visible in Loki and Grafana.
- Traces visible in Tempo and Grafana.

## Notes

This design keeps everything local while preserving real-world practices:
OTLP ingestion at a centralized gateway, pull-based Prometheus scraping,
and PV-backed storage for durable observability data. The stack can be
expanded by adding scaling, retention policies, and additional processors
or exporters in the OTel Collector.
