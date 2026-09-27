#!/usr/bin/env bash
set -euo pipefail
umask 022

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/../../build/build.conf"

# luci-theme-argon is not part of the official OpenWrt feeds; fetch it from
# upstream at a pinned release tag so the build is reproducible.
ARGON_REPO="https://github.com/jerrykuku/luci-theme-argon.git"
ARGON_TAG="v2.4.7"

fetch_git_ref() {
    local repo="$1"
    local ref="$2"
    local dest="$3"

    echo "    Cloning: ${repo} @ ${ref}"
    git init -q "$dest"
    git -C "$dest" remote add origin "$repo"
    git -C "$dest" fetch -q --depth 1 origin "$ref"
    git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD

    # Strip VCS metadata so the result is a plain OpenWrt package directory.
    rm -rf "$dest/.git" "$dest/.github"
    if [ ! -f "$dest/Makefile" ]; then
        echo "ERROR: ${dest} has no Makefile; not a valid OpenWrt package." >&2
        return 1
    fi
}

prepare_packages() {
    local work_dir="$1"
    echo "==> Fetching Web UI packages..."
    fetch_git_ref "$ARGON_REPO" "$ARGON_TAG" "${work_dir}/packages/luci-theme-argon"
    fetch_git_ref "https://github.com/gSpotx2f/luci-app-cpu-status.git" "$CPU_STATUS_COMMIT" \
        "${work_dir}/packages/luci-app-cpu-status"
    fetch_git_ref "https://github.com/gSpotx2f/luci-app-temp-status.git" "$TEMP_STATUS_COMMIT" \
        "${work_dir}/packages/luci-app-temp-status"
}

install_assets() {
    local work_dir="$1"

    # Only replace fetched packages; packages/moci is maintained in-tree.
    rm -rf "$SCRIPT_DIR/packages/luci-theme-argon" \
        "$SCRIPT_DIR/packages/luci-app-cpu-status" \
        "$SCRIPT_DIR/packages/luci-app-temp-status"
    mkdir -p "$SCRIPT_DIR/packages"

    cp -a "${work_dir}/packages/"* "$SCRIPT_DIR/packages/"

    echo "==> Web UI assets successfully prepared:"
    echo "    - Package: packages/luci-theme-argon (${ARGON_TAG})"
    echo "    - Package: packages/luci-app-cpu-status (${CPU_STATUS_COMMIT})"
    echo "    - Package: packages/luci-app-temp-status (${TEMP_STATUS_COMMIT})"
}

main() {
    echo "==> Synchronizing Web UI assets from upstream into: ${SCRIPT_DIR}..."

    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    prepare_packages "$tmpdir"
    install_assets "$tmpdir"
}

main "$@"
