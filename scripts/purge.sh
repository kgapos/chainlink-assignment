#!/bin/sh

# Purges all docker networks, containers, images and volumes.

set -eu

read -p "Are you sure you want to purge all docker networks, containers, images and volumes? (y/n) " answer
if [ "$answer" != "y" ]; then
  echo "Aborting..."
  exit 1
fi

docker network prune -f
docker container prune -f
docker image prune -af
docker volume prune -f

echo "Done."