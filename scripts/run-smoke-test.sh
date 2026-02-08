#!/bin/sh

# Runs a smoke test with k6.

set -eu

docker compose run --rm \
    -e TEST_PROFILE=smoke \
    k6

echo "Done."