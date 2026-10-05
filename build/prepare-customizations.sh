#!/usr/bin/env bash
# Functions for customizations.
umask 022

source "$(dirname -- "${BASH_SOURCE[0]}")/build.conf"

apply_source_patches() {
    local patch_file
    for patch_file in "$CUSTOM"/*/tree-patches/*.patch; do
        [[ -e "${patch_file%/tree-patches/*}/.skip" ]] && continue
        echo "==> Tree patch: $(basename "$patch_file")"
        patch -p1 --batch --fuzz=0 < "$patch_file"
    done
}

copy_custom_packages() {
    local dir
    for dir in "$CUSTOM"/*/packages/; do
        [[ -e "${dir%/packages/}/.skip" ]] && continue
        rsync -a "$dir" package/
    done
}

copy_package_patches() {
    local patch_dir pkg_dir
    local -a patch_files matches

    for patch_dir in "$CUSTOM"/*/patches/*/; do
        [[ -e "${patch_dir%/patches/*/}/.skip" ]] && continue
        patch_files=("$patch_dir"*.patch)
        if (( ${#patch_files[@]} == 0 )); then
            continue
        fi
        mapfile -t matches < <(
            find package feeds -type d -name "$(basename "$patch_dir")" \
                -not -path 'package/feeds/*' \
                -exec test -f '{}/Makefile' \; -print
        )
        if (( ${#matches[@]} != 1 )); then
            die "Expected exactly one package directory, found ${#matches[@]}: $patch_dir"
        fi
        pkg_dir=${matches[0]}
        echo "==> Patches: $patch_dir -> $pkg_dir/patches/"
        mkdir -p "$pkg_dir/patches"
        install -m 644 "${patch_files[@]}" "$pkg_dir/patches/"
    done
}

copy_custom_files() {
    local dir
    rm -rf -- "$TREE/files"
    mkdir -p "$TREE/files"
    for dir in "$CUSTOM"/*/files/; do
        [[ -e "${dir%/files/}/.skip" ]] && continue
        rsync -a "$dir" "$TREE/files/"
    done
}

prepare_config() {
    local config_file
    : > .config
    for config_file in "$CUSTOM"/*/config.fragment; do
        [[ -e "${config_file%/config.fragment}/.skip" ]] && continue
        cat "$config_file" >> .config
    done
}

prepare_permissions() {
    local dir
    local -a dirs=()

    for dir in package feeds target files; do
        if [[ -d "$TREE/$dir" ]]; then
            dirs+=("$TREE/$dir")
        fi
    done
    if (( ${#dirs[@]} == 0 )); then
        return
    fi

    # Repair old 0666/0777 checkouts before package copies preserve their modes.
    # Touch repaired files so OpenWrt also invalidates cached package builds.
    # Keep executable bits, Git metadata and generated rootfs permissions intact.
    find "${dirs[@]}" -name .git -prune -o \
        -type d -perm /022 -exec chmod go-w -- {} + -o \
        -type f -perm /022 -exec chmod go-w -- {} + -exec touch -- {} +
}

prepare_customizations() (
    cd "$TREE"
    shopt -s nullglob

    apply_source_patches
    copy_custom_packages
    copy_package_patches
    copy_custom_files
    prepare_config
    prepare_permissions
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
    prepare_customizations
fi
