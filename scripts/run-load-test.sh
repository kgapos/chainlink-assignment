#!/bin/sh

# Runs a load test with k6.

set -eu

docker compose run --rm \
    -e TEST_PROFILE=load \
    -e MAX_VUS=${MAX_VUS:-1000} \
    -e STAGE_DURATION=${STAGE_DURATION:-30s} \
    k6

echo "Done."