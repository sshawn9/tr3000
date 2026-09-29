#!/usr/bin/env bash
set -euo pipefail
umask 077

TARGET=${1:-root@10.0.0.1}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mkdir -p -- "$SCRIPT_DIR/snapshots"
SNAPSHOT=$(mktemp -d "$SCRIPT_DIR/snapshots/$(date +%Y-%m-%d_%H%M%S).XXXXXX")

backup_preset() {
    rsync -a -e ssh -- "${TARGET}:/etc/preset.d/" "$SNAPSHOT/preset.d/"
}

backup_mihomo() {
    rsync -a -e ssh -- "${TARGET}:/etc/mihomo/" "$SNAPSHOT/mihomo/"
}

backup_root_password() {
    rsync -a -e ssh -- "${TARGET}:/etc/shadow" "$SNAPSHOT/"
}

main() {
    backup_preset
    backup_mihomo
    backup_root_password
    printf '备份完成：%s\n' "$SNAPSHOT"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
