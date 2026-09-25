#!/usr/bin/env bash
set -euo pipefail
umask 022

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# OpenWrt-nikki: mihomo core package (built from source with the golang feed)
# plus the nikki transparent-proxy engine. Pinned to a main-branch commit rather
# than a release tag because release tags lag behind on the mihomo core version.
NIKKI_REPO="https://github.com/nikkinikki-org/OpenWrt-nikki.git"
NIKKI_COMMIT="7b203f6c4c5e94c6c0026acb301090aa1d310e7f"   # 2026-09-17, mihomo-meta 1.19.31, nikki 2026.04.08

# Packages taken from the repo. luci-app-nikki is copied so it can be selected
# later, but it is not enabled in config.fragment.
NIKKI_PACKAGES="mihomo-meta nikki luci-app-nikki"

fetch_git_commit() {
    local repo="$1" commit="$2" dest="$3"

    echo "    Cloning: ${repo} @ ${commit}"
    git init -q "$dest"
    git -C "$dest" remote add origin "$repo"
    git -C "$dest" fetch -q --depth 1 origin "$commit"
    git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD
}

prepare_packages() {
    local work_dir="$1" src pkg
    src="${work_dir}/src"

    echo "==> [1/1] Fetching OpenWrt-nikki packages..."
    fetch_git_commit "$NIKKI_REPO" "$NIKKI_COMMIT" "$src"

    mkdir -p "${work_dir}/packages"
    for pkg in $NIKKI_PACKAGES; do
        if [ ! -f "${src}/${pkg}/Makefile" ]; then
            echo "ERROR: ${pkg}/Makefile not found in OpenWrt-nikki @ ${NIKKI_COMMIT}" >&2
            return 1
        fi
        cp -a "${src}/${pkg}" "${work_dir}/packages/${pkg}"
    done
}

install_assets() {
    local work_dir="$1" pkg

    rm -rf "$SCRIPT_DIR/packages"
    mkdir -p "$SCRIPT_DIR/packages"

    cp -a "${work_dir}/packages/"* "$SCRIPT_DIR/packages/"

    echo "==> mihomo assets successfully prepared:"
    for pkg in $NIKKI_PACKAGES; do
        echo "    - Package: packages/${pkg} ($(grep -E '^PKG_VERSION' "$SCRIPT_DIR/packages/${pkg}/Makefile" | head -1 | cut -d= -f2))"
    done
}

main() {
    echo "==> Synchronizing mihomo assets from upstream into: ${SCRIPT_DIR}..."

    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    prepare_packages "$tmpdir"
    install_assets "$tmpdir"
}

main "$@"
