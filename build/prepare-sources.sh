#!/usr/bin/env bash
# Functions for sources.

source "$(dirname -- "${BASH_SOURCE[0]}")/build.conf"

clone_source() (
    mkdir -p "$TREE"
    cd "$TREE"
    git init --initial-branch="$OPENWRT_BRANCH"
    git remote add -t "$OPENWRT_BRANCH" origin "$OPENWRT_REPO"
    git fetch --depth 1 origin
    git checkout -B "$OPENWRT_BRANCH" --track "origin/$OPENWRT_BRANCH"
    ./scripts/feeds update -a
)

clean_source() (
    cd "$TREE"
    git checkout -f "$OPENWRT_BRANCH"
    git clean -fd
    while read -r feed_name _feed_type _feed_revision feed_url; do
        cd "$TREE/feeds/$feed_name"
        git checkout -f "${feed_url##*;}"
        git clean -fd
    done < <(./scripts/feeds list -s)
)

prepare_source() {
    if [[ ! -d "$TREE/.git" ]]; then
        clone_source
    fi
    clean_source
    cd "$TREE"
    ./scripts/feeds install -a
}

update_sources() (
    prepare_source
    cd "$TREE"
    git pull --ff-only
    ./scripts/feeds update -a
    clean_source
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    case "${1:-}" in
        '') prepare_source ;;
        --update) update_sources ;;
        *) printf 'Usage: %s [--update]\n' "$0" >&2; exit 1 ;;
    esac
fi
