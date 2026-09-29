#!/usr/bin/env bash
set -euo pipefail
umask 022

source "$(dirname -- "${BASH_SOURCE[0]}")/build.conf"

run_in_container() {
    local workdir="$1"
    shift

    # docker exec does not inherit the calling shell's umask.
    docker exec -w "$workdir" "$CONTAINER" \
        bash -c 'umask 022; exec "$@"' -- "$@"
}

build_firmware() {
    bash "$DOCKER_DIR/start.sh"

    run_in_container "$CONTAINER_BASE" bash "$CONTAINER_BASE/prepare-sources.sh"
    run_in_container "$CONTAINER_BASE" bash "$CONTAINER_BASE/prepare-customizations.sh"
    run_in_container "$CONTAINER_TREE" make defconfig
    run_in_container "$CONTAINER_TREE" make -j"$JOBS" download
    run_in_container "$CONTAINER_TREE" make -j"$JOBS" "$@"

    mkdir -p "$OUTPUT"
    rsync -a --delete "$TREE/bin/" "$OUTPUT/"
    cp "$TREE/.config" "$OUTPUT/build.config"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    build_firmware "$@"
fi
