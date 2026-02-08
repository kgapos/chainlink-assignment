#!/bin/sh

set -eu

cat << 'EOF'
Purpose: Where is the system's upper limit?

What you are looking for:
  - Maximum sustainable throughput
  - Bottlenecks (CPU, DB, locks, queues)
  - Failure modes (timeouts vs errors)
  - How the system behaves when overloaded

Load characteristics:
  - Continuously increasing load (up 5000 VUs)
  - Shorter duration (2 minutes, 4 * 30s stages)
  - Stops once performance collapses
EOF

docker compose run --rm \
  -e TEST_PROFILE=load \
  -e MAX_VUS=${MAX_VUS:-5000} \
  -e STAGE_DURATION=${STAGE_DURATION:-30s} \
  k6

echo "Saturation test done."