#!/bin/sh
set -eu

cat << 'EOF'
Purpose: Downloads alert rules from Grafana and saves them to the project's alerting directory.
EOF

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"
OUTPUT_PATH="${1:-grafana/alerting/alerts.yaml}"

tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

echo "Exporting alert rules from ${GRAFANA_URL}..."
curl -fsS \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  "${GRAFANA_URL}/api/v1/provisioning/alert-rules/export?format=yaml" \
  -o "$tmp_file"

if ! grep -q '^apiVersion:' "$tmp_file"; then
  echo "Failed: export does not look like Grafana alert provisioning YAML."
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
mv "$tmp_file" "$OUTPUT_PATH"

echo "Updated ${OUTPUT_PATH}"
