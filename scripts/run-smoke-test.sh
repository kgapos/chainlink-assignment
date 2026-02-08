#!/bin/sh
set -eu

cat << 'EOF'
Purpose: Does the system work at all under minimal load? Run after code changes for validation.

What you are validating:
  - The script itself works
  - Endpoints respond correctly
  - Basic application and telemetry flows are correct
  - No obvious 500s, timeouts, or crashes

Load characteristics:
  - Very low traffic (10 VUs)
  - Short duration (10 seconds)
EOF

docker compose run --rm \
  -e TEST_PROFILE=smoke \
  k6

echo "Smoke test done."