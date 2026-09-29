#!/usr/bin/env bash
set -euo pipefail
umask 022

source "$(dirname -- "${BASH_SOURCE[0]}")/../build.conf"

prepare_image() {
    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        docker build --network=host -t "$IMAGE" -f "$DOCKER_DIR/Dockerfile" "$DOCKER_DIR"
    fi
}

create_container() {
    if ! docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        prepare_image
        mkdir -p "$WORK"
        docker create --name "$CONTAINER" --init --network host \
            --user "$(id -u):$(id -g)" --label "wrt.build=$BASE" \
            --mount "type=bind,src=/etc/localtime,dst=/etc/localtime,readonly" \
            --mount "type=bind,src=$PROJECT,dst=$CONTAINER_PROJECT,readonly" \
            --mount "type=bind,src=$BASE,dst=$CONTAINER_BASE" \
            --mount "type=bind,src=$WORK,dst=$CONTAINER_WORK" \
            --workdir "$CONTAINER_BASE" \
            "$IMAGE" sleep infinity
    fi
}

start_container() {
    create_container
    if [[ $(docker container inspect -f '{{.State.Running}}' "$CONTAINER") != true ]]; then
        docker start "$CONTAINER"
    fi
}

start_container
