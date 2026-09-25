#!/usr/bin/env bash
set -euo pipefail
umask 022

source "$(dirname -- "${BASH_SOURCE[0]}")/build.conf"

bash "$DOCKER_DIR/start.sh"

docker exec -w "$CONTAINER_BASE" "$CONTAINER" bash "$CONTAINER_BASE/prepare-sources.sh"
docker exec -w "$CONTAINER_BASE" "$CONTAINER" bash "$CONTAINER_BASE/prepare-customizations.sh"
docker exec -w "$CONTAINER_TREE" "$CONTAINER" make defconfig
docker exec -w "$CONTAINER_TREE" "$CONTAINER" make -j"$JOBS" download
docker exec -w "$CONTAINER_TREE" "$CONTAINER" make -j"$JOBS" "$@"

mkdir -p "$OUTPUT"
rsync -a --delete "$TREE/bin/" "$OUTPUT/"
cp "$TREE/.config" "$OUTPUT/build.config"
