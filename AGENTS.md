# Designing an End-to-End Observability Pipeline (Local)

## Goal
Design and document a complete local observability pipeline that ingests and stores metrics, logs, and traces from a VeChain node. The system runs entirely on Docker Compose, receives OTLP telemetry, and persists data via local Docker volumes.

## Architecture Overview
Local container orchestration: Docker Compose with named volumes for persistence.

Core components:
- **OpenTelemetry Collector** (gateway): OTLP ingestion, processing, routing.
- **Metrics**: Prometheus (scrape + TSDB storage).
- **Logs**: Loki (log store) + Promtail (agent) or OTel Collector log receiver.
- **Traces**: Tempo (trace store).
- **Visualization**: Grafana.

Signal ingress:
- **OTLP gRPC/HTTP** from a sidecar trace generator to the OTel Collector gateway.
- **Prometheus pull** for metrics scraping (VeChain node exposes `/metrics` when enabled).

Persistence:
- Prometheus TSDB -> Docker volume
- Loki chunks + index -> Docker volume
- Tempo blocks + WAL -> Docker volume
- Grafana dashboards -> Docker volume

## Logical Pipelines

### Metrics Pipeline
1. VeChain node exposes `/metrics` (Prometheus format).
2. Prometheus scrapes targets defined in static configs (Compose network DNS).
3. Prometheus stores metrics in local volume-backed TSDB.
4. OTel Collector can also accept OTLP metrics and remote_write to Prometheus (optional).

### Logs Pipeline
1. VeChain node emits stdout/stderr to container logs.
2. Promtail tails container logs and forwards to Loki.
3. Loki stores logs locally with volume-backed chunks and index.

### Traces Pipeline
1. A sidecar trace generator emits OTLP traces to the OTel Collector.
2. OTel Collector receives, batches, and forwards to Tempo.
3. Tempo stores traces in volume-backed blocks with WAL.

## Dataflow Diagrams

### Context Diagram
```
                +---------------------------+
                |        VeChain Node       |
                | (metrics/logs) + Sidecar  |
                |       (traces)            |
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
        Docker volume storage             Docker volume TSDB

                    +----------------+
                    |     Loki       |
  Promtail -------->|    (logs)      |
                    +-------+--------+
                            |
                            v
                     Docker volume storage

                +----------------------+
                |      Grafana         |
                |  Dashboards/Explore  |
                +----------+-----------+
                           |
                           v
                    Docker volume storage
```

### Sequence Diagram (OTLP Traces)
```
Trace Sidecar -> OTel Collector: OTLP trace spans
OTel Collector -> OTel Collector: batch/attributes sampling
OTel Collector -> Tempo: OTLP export
Tempo -> Docker volume: write WAL + blocks
Grafana -> Tempo: query trace by trace_id
```

### Sequence Diagram (Prometheus Metrics)
```
Prometheus -> VeChain Node: GET /metrics
VeChain Node -> Prometheus: Prometheus text exposition
Prometheus -> Docker volume: append TSDB blocks
Grafana -> Prometheus: query metrics (PromQL)
```

### Sequence Diagram (Logs)
```
VeChain Node -> Container runtime: stdout/stderr
Promtail -> Container runtime: tail logs
Promtail -> Loki: push batches
Loki -> Docker volume: store chunks + index
Grafana -> Loki: query logs (LogQL)
```

## Local Docker Compose Stack

Recommended versions (example images):
- OpenTelemetry Collector: `otel/opentelemetry-collector-contrib`
- Prometheus: `prom/prometheus`
- Loki: `grafana/loki`
- Tempo: `grafana/tempo`
- Grafana: `grafana/grafana`

Services (Compose):
- `otel-collector`, `prometheus`, `loki`, `tempo`, `grafana`, `promtail`, `vechain-node`, `trace-sidecar`

## Storage & Persistence

Use named Docker volumes for Prometheus, Loki, Tempo, Grafana, and VeChain node data.

Persistence plan:
- Prometheus: TSDB data
- Loki: chunks + index
- Tempo: WAL + blocks
- Grafana: dashboards and sqlite
- VeChain node: chain data (`thor_data`)

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

- Use resource limits to avoid noisy neighbor issues.
- Run containers as non-root where possible.
- Keep configuration in versioned files mounted as read-only.

## Optional Proof-of-Concept (Bonus)

Example demo app:
- `vechain-node` service configured to expose `/metrics` and emit logs.
- `trace-sidecar` service configured to emit OTLP traces.

Example configuration layout:
- `docker-compose.yaml`
- `otel-collector.yaml`
- `prometheus.yaml`
- `loki.yaml`
- `tempo.yaml`
- `grafana.yaml`
- `promtail.yaml`
- `grafana/datasources.yaml`
- `grafana/dashboards.yaml`
- `grafana/dashboards/overview.json`

## Validation Checklist

- `docker compose ps` shows all services healthy.
- Grafana connects to Prometheus, Loki, and Tempo.
- Metrics visible in Prometheus and Grafana.
- Logs visible in Loki and Grafana.
- Traces visible in Tempo and Grafana.

## Notes

This design keeps everything local while preserving real-world practices:
OTLP ingestion at a centralized gateway, pull-based Prometheus scraping,
and volume-backed storage for durable observability data. The stack can be
expanded by adding scaling, retention policies, and additional processors
or exporters in the OTel Collector.

## Design Guardrails

- Use Docker Compose for local orchestration.
- Use named volumes for persistence, including `thor_data`.
- Use Promtail for log shipping to Loki.
- Use a trace sidecar to emit OTLP traces (VeChain node does not emit traces).
- Auto-provision Grafana data sources and at least one starter dashboard.
