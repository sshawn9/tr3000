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

# wireless-regdb data patch (ImmortalWrt): raises the CN regulatory limits so the
# radio can run at its EEPROM-calibrated maximum and use 160 MHz on 36-64.
#   2.4 GHz            20 -> 30 dBm
#   5150-5350 (36-64)  23/20 dBm, 80 MHz, DFS  ->  30 dBm, 160 MHz, no DFS
#   5725-5850 (149-165) unchanged (33 dBm, 80 MHz)
# The country code stays CN so clients keep following their own CN channel tables.
prepare_patches() {
    local work_dir="$1"
    echo "==> [1/1] Fetching wireless-regdb txpower/DFS patch..."
    fetch_remote_file \
        "package/firmware/wireless-regdb/patches/600-custom-change-txpower-and-dfs.patch" \
        "${work_dir}/patches/wireless-regdb/600-custom-change-txpower-and-dfs.patch"
}

install_assets() {
    local work_dir="$1"

    rm -rf "$SCRIPT_DIR/patches"
    mkdir -p "$SCRIPT_DIR/patches"

    cp -a "${work_dir}/patches/"* "$SCRIPT_DIR/patches/"

    echo "==> Wi-Fi unlock assets successfully prepared:"
    echo "    - Patches: patches/wireless-regdb/600-custom-change-txpower-and-dfs.patch"
}

main() {
    echo "==> Synchronizing Wi-Fi unlock assets from upstream into: ${SCRIPT_DIR}..."

    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    prepare_patches "$tmpdir"
    install_assets "$tmpdir"
}

main "$@"
