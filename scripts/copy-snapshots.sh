#!/bin/sh

# Copies snapshots into the node data directories if the USE_SNAPSHOT environment variable is true.
# Changes the ownership of the node data directories to the THOR_UID and THOR_GID.

set -eu

SNAPSHOT_DIR="${SNAPSHOT_DIR:-/snapshot}"
NODE_A_DIR="${NODE_A_DIR:-/node_data_a}"
NODE_B_DIR="${NODE_B_DIR:-/node_data_b}"
THOR_UID="${THOR_UID:-1000}"
THOR_GID="${THOR_GID:-1000}"
USE_SNAPSHOT="${USE_SNAPSHOT:-true}"

copy_into_dir() {
  target_dir="$1"

  mkdir -p "$target_dir"

  if [ "$(ls -A "$target_dir" 2>/dev/null)" ]; then
    echo "${target_dir} already contains files; skipping snapshot copy and ownership changes to avoid touching existing data."
    return
  fi

  if [ "$USE_SNAPSHOT" = "true" ]; then
    if [ -d "$SNAPSHOT_DIR" ] && [ "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]; then
      echo "Copying snapshot into ${target_dir} (this may take a while)..."
      cp -a "$SNAPSHOT_DIR"/. "$target_dir"/
    else
      echo "No snapshots found in ${SNAPSHOT_DIR}; skipping copy for ${target_dir}."
    fi
  else
    echo "USE_SNAPSHOT=${USE_SNAPSHOT}; skipping snapshot copy for ${target_dir}."
  fi

  echo "Fixing ownership in ${target_dir} to ${THOR_UID}:${THOR_GID}..."
  chown -R "${THOR_UID}:${THOR_GID}" "$target_dir"
}

copy_into_dir "$NODE_A_DIR"
copy_into_dir "$NODE_B_DIR"

echo "Done."
