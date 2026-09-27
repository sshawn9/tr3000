#!/usr/bin/env bash
set -euo pipefail
umask 022

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/../../build/build.conf"
UPSTREAM_BASE="https://raw.githubusercontent.com/immortalwrt/immortalwrt/$IMMORTALWRT_COMMIT"

fetch_remote_file() {
    local remote_path="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"
    echo "    Fetching: ${remote_path}"
    curl --fail --location --retry 3 -sS "${UPSTREAM_BASE}/${remote_path}" -o "$dest"
    if [ ! -s "$dest" ]; then
        echo "ERROR: Downloaded file ${dest} is empty." >&2
        return 1
    fi
}

prepare_packages() {
    local work_dir="$1"
    echo "==> [1/2] Fetching kernel module package (fullconenat-nft)..."
    fetch_remote_file \
        "package/network/utils/fullconenat-nft/Makefile" \
        "${work_dir}/packages/fullconenat-nft/Makefile"

    # Upstream nft-fullcone (2023) still uses the 3-arg nft_expr_ops->validate
    # signature; kernel 6.12 dropped the third argument. Without this in-package
    # patch, kmod-nft-fullcone fails to compile on OpenWrt 25.12 (GCC 14 treats
    # incompatible-pointer-types as an error).
    fetch_remote_file \
        "package/network/utils/fullconenat-nft/patches/010-fix-build-with-kernel-6.12.patch" \
        "${work_dir}/packages/fullconenat-nft/patches/010-fix-build-with-kernel-6.12.patch"
}

# Component patches are stored as patches/<package-name>/<patch>; build.sh
# resolves <package-name> to the package directory in the OpenWrt tree and
# copies the patch into its patches/ directory.
prepare_patches() {
    local work_dir="$1"
    echo "==> [2/2] Fetching 3 independent upstream component patches..."

    fetch_remote_file \
        "package/network/config/firewall4/patches/001-firewall4-add-support-for-fullcone-nat.patch" \
        "${work_dir}/patches/firewall4/001-firewall4-add-support-for-fullcone-nat.patch"

    # Renumbered 002 -> 010: official nftables already ships 001-003 build patches.
    fetch_remote_file \
        "package/network/utils/nftables/patches/002-nftables-add-fullcone-expression-support.patch" \
        "${work_dir}/patches/nftables/010-nftables-add-fullcone-expression-support.patch"

    fetch_remote_file \
        "package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch" \
        "${work_dir}/patches/libnftnl/001-libnftnl-add-fullcone-expression-support.patch"
}

install_assets() {
    local work_dir="$1"

    rm -rf "$SCRIPT_DIR/packages" "$SCRIPT_DIR/patches"
    mkdir -p "$SCRIPT_DIR/packages" "$SCRIPT_DIR/patches"

    cp -a "${work_dir}/packages/"* "$SCRIPT_DIR/packages/"
    cp -a "${work_dir}/patches/"* "$SCRIPT_DIR/patches/"

    echo "==> FullCone NAT assets successfully prepared:"
    echo "    - Package: packages/fullconenat-nft/Makefile"
    echo "               packages/fullconenat-nft/patches/010-fix-build-with-kernel-6.12.patch"
    echo "    - Patches: patches/firewall4/001-firewall4-add-support-for-fullcone-nat.patch"
    echo "               patches/nftables/010-nftables-add-fullcone-expression-support.patch"
    echo "               patches/libnftnl/001-libnftnl-add-fullcone-expression-support.patch"
}

main() {
    echo "==> Synchronizing FullCone NAT assets from upstream into: ${SCRIPT_DIR}..."

    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    prepare_packages "$tmpdir"
    prepare_patches "$tmpdir"
    install_assets "$tmpdir"
}

main "$@"
