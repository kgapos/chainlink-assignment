#!/bin/sh

set -eu

cat << 'EOF'
Purpose: Does the system stay stable over time under sustained load?

What you are looking for:
  - Memory leaks
  - File descriptor leaks
  - Connection pool exhaustion
  - Gradual latency creep
  - Increasing error rates over time
  - GC / cache / DB issues that only appear later

Load characteristics:
  - Steady load
  - At or slightly below expected production load (1000 VUs)
  - Long duration (1 hour, 4 * 15 minute stages)
EOF

docker compose run --rm \
  -e TEST_PROFILE=load \
  -e MAX_VUS=${MAX_VUS:-1000} \
  -e STAGE_DURATION=${STAGE_DURATION:-15m} \
  k6

echo "Soak test done."