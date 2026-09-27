#!/usr/bin/env bash
# Functions for sources.

source "$(dirname -- "${BASH_SOURCE[0]}")/build.conf"

clone_source() (
    mkdir -p "$TREE"
    cd "$TREE"
    git init --initial-branch="$OPENWRT_BRANCH"
    git remote add -t "$OPENWRT_BRANCH" origin "$OPENWRT_REPO"
    git fetch --depth 1 origin "$OPENWRT_COMMIT"
    git checkout --detach "$OPENWRT_COMMIT"
    cp "$BASE/feeds.conf" feeds.conf
    ./scripts/feeds update -a
)

clean_source() (
    cd "$TREE"
    if ! git cat-file -e "$OPENWRT_COMMIT^{commit}" 2>/dev/null; then
        git fetch --depth 1 origin "$OPENWRT_COMMIT"
    fi
    git checkout -f --detach "$OPENWRT_COMMIT"
    git clean -fd
    cp "$BASE/feeds.conf" feeds.conf
    while read -r feed_name _feed_type _feed_revision feed_url; do
        cd "$TREE"
        if [[ ! -d "feeds/$feed_name/.git" ]]; then
            ./scripts/feeds update "$feed_name"
        fi
        cd "$TREE/feeds/$feed_name"
        feed_commit=${feed_url##*^}
        if ! git cat-file -e "$feed_commit^{commit}" 2>/dev/null; then
            git fetch --depth 1 origin "$feed_commit"
        fi
        git checkout -f --detach "$feed_commit"
        git clean -fd
    done < <(./scripts/feeds list -s)
)

prepare_source() {
    if [[ ! -d "$TREE/.git" ]]; then
        clone_source
    fi
    clean_source
    cd "$TREE"
    ./scripts/feeds update -a -i
    ./scripts/feeds install -a
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    case "${1:-}" in
        '') prepare_source ;;
        *) printf 'Usage: %s\n' "$0" >&2; exit 1 ;;
    esac
fi
