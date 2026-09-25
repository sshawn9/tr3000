#!/usr/bin/env bash
set -euo pipefail
umask 022

source "$(dirname -- "${BASH_SOURCE[0]}")/build.conf"

install_dependencies() {
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bc bison build-essential bzip2 ca-certificates ccache clang curl \
        debianutils device-tree-compiler diffutils file flex g++-multilib gawk gcc-multilib \
        gettext git libelf-dev libncurses-dev libssl-dev lld llvm patch perl \
        pkgconf python3 python3-dev python3-pyelftools python3-setuptools \
        qemu-utils quilt rsync subversion swig time unzip util-linux wget \
        xz-utils zlib1g-dev zstd
}

build_firmware() (
    bash "$CUSTOM/prepare.sh"
    bash "$BASE/prepare-sources.sh"
    bash "$BASE/prepare-customizations.sh"

    cd "$TREE"
    make defconfig
    make -j"$JOBS" download
    make -j"$JOBS" "$@"

    mkdir -p "$OUTPUT"
    rsync -a --delete "$TREE/bin/" "$OUTPUT/"
    cp "$TREE/.config" "$OUTPUT/build.config"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    install_dependencies
    build_firmware "$@"
fi
