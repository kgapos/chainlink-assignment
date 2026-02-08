# Designing an End-to-End Observability Pipeline (Local)

## Goal

Design and document a complete local observability pipeline that ingests and stores metrics, logs, and traces from a VeChain node. The system runs entirely on Docker Compose, receives OTLP telemetry, and persists data via local Docker volumes.

## Architecture Overview

Local container orchestration: Docker Compose with named volumes for persistence.

Core components:

- **OpenTelemetry Collector** (gateway): OTLP ingestion, processing, routing.
- **Metrics**: Prometheus (scrape + TSDB storage).
- **Logs**: Loki (log store) via OTel Collector log receiver.
- **Traces**: Tempo (trace store).
- **Visualization**: Grafana.

Signal ingress:

- **OTLP gRPC/HTTP** from the Envoy edge proxy to the OTel Collector gateway.
- **Prometheus pull** for metrics scraping (VeChain node exposes `/metrics` when enabled).

Persistence:

- Prometheus TSDB -> Docker volume
- Loki chunks + index -> Docker volume
- Tempo blocks + WAL -> Docker volume
- Grafana dashboards -> Docker volume

## Logical Pipelines

### Metrics Pipeline

1. VeChain node exposes `/metrics` (Prometheus format).
2. OTel Collector scrapes node and platform metrics with the Prometheus receiver.
3. OTel Collector exposes aggregated metrics on a Prometheus exporter endpoint.
4. Prometheus scrapes the OTel Collector exporter and stores TSDB data in a local volume.

### Logs Pipeline

1. VeChain node emits stdout/stderr to container logs.
2. OTel Collector tails container logs and forwards to Loki.
3. Loki stores logs locally with volume-backed chunks and index.

### Traces Pipeline

1. Envoy edge proxy emits OTLP traces for API requests to the OTel Collector.
2. OTel Collector receives, batches, and forwards to Tempo.
3. Tempo stores traces in volume-backed blocks with WAL.

## Dataflow Diagrams

### Context Diagram

```
                +---------------------------+
                |        Envoy Proxy        |
                |  (public API + traces)    |
                +-------------+-------------+
                              |
            proxied requests  |    OTLP gRPC/HTTP
                              |           |
                              v           v
                +---------------------------+
                | VeChain Nodes (A/B)       |
                |   (metrics + logs)        |
                +-------------+-------------+
                              |
                           /metrics
                              |
                              v
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
 OTel Collector --->|    (logs)      |
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
Envoy -> OTel Collector: OTLP trace spans
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
OTel Collector -> Container runtime: tail logs
OTel Collector -> Loki: push batches
Loki -> Docker volume: store chunks + index
Grafana -> Loki: query logs (LogQL)
```

## Local Docker Compose Stack

Recommended versions (example images):

- OpenTelemetry Collector: `otel/opentelemetry-collector`
- Prometheus: `prom/prometheus`
- Loki: `grafana/loki`
- Tempo: `grafana/tempo`
- Grafana: `grafana/grafana`

Services (Compose):

- `envoy`, `otel-collector`, `prometheus`, `loki`, `tempo`, `grafana`, `node-a`, `node-b`, `k6` (profile: `loadtest`)

## Storage & Persistence

Use named Docker volumes for Prometheus, Loki, Tempo, Grafana, and per-node VeChain data.

Persistence plan:

- Prometheus: TSDB data
- Loki: chunks + index
- Tempo: WAL + blocks
- Grafana: dashboards and sqlite
- VeChain node A: chain data (`node_data_a`)
- VeChain node B: chain data (`node_data_b`)

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

- `node-a` and `node-b` services configured to expose `/metrics` and emit logs.
- `envoy` service load-balances public API traffic to `node-a` and `node-b`.
- `envoy` emits OTLP traces for API requests to the OTel Collector.

Example configuration layout:

- `compose.yaml`
- `k6/run.js`
- `k6/requests.ndjson`
- `otel-collector.yaml`
- `prometheus.yaml`
- `loki.yaml`
- `tempo.yaml`
- `grafana.yaml`
- `grafana/datasources.yaml`
- `grafana/dashboards.yaml`
- `grafana/dashboards/overview.json`

## Validation Checklist

- `docker compose ps` shows all services healthy.
- Grafana connects to Prometheus, Loki, and Tempo.
- Metrics visible in Prometheus and Grafana.
- Logs visible in Loki and Grafana.
- Traces visible in Tempo and Grafana.

## Basic Tests After Changes

- `docker compose pull` to validate image access.
- `docker compose up -d` to ensure services start.
- `docker compose ps` to confirm healthy status.
- `docker logs -n 20 node-a` and `docker logs -n 20 node-b` to confirm nodes are running and syncing.
- `curl http://localhost:80/blocks/best` to generate edge API traffic.
- `curl "http://localhost:3200/api/search?q={resource.service.name = \"edge-proxy\"}"` to confirm traces are stored.
- `docker compose --profile loadtest run --rm -e TEST_PROFILE=smoke k6` to validate synthetic load generation.

## Notes

This design keeps everything local while preserving real-world practices:
OTLP ingestion at a centralized gateway, pull-based Prometheus scraping,
and volume-backed storage for durable observability data. The stack can be
expanded by adding scaling, retention policies, and additional processors
or exporters in the OTel Collector.

## Design Guardrails

- Use Docker Compose for local orchestration.
- Use named volumes for persistence, including per-node `node_data` volumes.
- Use OTel Collector for log shipping to Loki.
- Use Envoy edge proxy to emit OTLP traces for node API traffic.
- Auto-provision Grafana data sources and at least one starter dashboard.
- Keep API public via edge proxy only; keep VeChain P2P ports internal.
- Use separate named volumes per node (`node_data_a`, `node_data_b`) for safe horizontal scaling.
- Format edited files with Prettier (`esbenp.prettier-vscode`), consistent with `.vscode/settings.json`.
