#!/bin/sh

# Purges all docker networks, containers, images and volumes.

set -eu

docker network prune -f
docker container prune -f
docker image prune -a -f
docker volume prune -f

echo "Done."