#!/bin/sh
set -eu

cat << 'EOF'
Purpose: Purges all docker networks, containers, images and volumes.

|-------------------|
| Use with caution! |
|-------------------|
This deletes all docker networks, containers, images and volumes, not just the ones created by this project.
EOF


read -p "Are you sure you want to purge all docker networks, containers, images and volumes? (y/n) " answer
if [ "$answer" != "y" ]; then
  echo "Aborting..."
  exit 1
fi

docker network prune -f
docker container prune -f
docker image prune -af
docker volume rm $(docker volume ls -q)

echo "Docker purged."