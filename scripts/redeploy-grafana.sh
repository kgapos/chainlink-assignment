#!/bin/sh
set -eu

cat << 'EOF'
Purpose: Redeploys Grafana so provisioned dashboard JSON files are reloaded.
  - Recreates only the grafana service
  - Waits for Grafana health endpoint to report OK
EOF

docker compose up -d --no-deps --force-recreate grafana

if command -v curl >/dev/null 2>&1; then
  echo "Waiting for Grafana to become healthy..."
  attempts=0
  until curl -fsS "http://localhost:3000/api/health" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "Grafana health check did not pass in time."
      echo "Inspect logs with: docker logs grafana"
      exit 1
    fi
    sleep 2
  done
fi

echo "Grafana dashboards redeployed."
