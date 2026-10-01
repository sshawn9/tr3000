#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
SNAPSHOT=${1:-}
if [[ -z "$SNAPSHOT" ]]; then
    for directory in "$SCRIPT_DIR"/snapshots/*/; do
        [[ -d "$directory" ]] || continue
        SNAPSHOT=$directory
    done
    [[ -n "$SNAPSHOT" ]] || { printf 'No backups found\n' >&2; exit 1; }
fi
SNAPSHOT=$(cd -- "$SNAPSHOT" && pwd -P)
TARGET=${2:-root@10.0.0.1}

setup_ssh_key() {
    ssh-copy-id -- "$TARGET"
}

restore_preset() {
    [[ -e "$SNAPSHOT/etc/preset.d" ]] || { printf 'Skipping missing etc/preset.d\n' >&2; return 0; }
    rsync -a --chown=root:root -e ssh -- "$SNAPSHOT/etc/preset.d/" "${TARGET}:/etc/preset.d/"
}

restore_mihomo() {
    [[ -e "$SNAPSHOT/etc/mihomo" ]] || { printf 'Skipping missing etc/mihomo\n' >&2; return 0; }
    rsync -a --chown=root:root -e ssh -- "$SNAPSHOT/etc/mihomo/" "${TARGET}:/etc/mihomo/"
}

restore_root_password() {
    [[ -e "$SNAPSHOT/etc/shadow" ]] || { printf 'Skipping missing etc/shadow\n' >&2; return 0; }
    local entry

    entry=$(awk -F: '$1 == "root" { print $1 ":" $2; found = 1; exit } END { if (!found) exit 1 }' "$SNAPSHOT/etc/shadow")
    printf '%s\n' "$entry" | ssh -T -- "$TARGET" 'chpasswd -e'
}

main() {
    setup_ssh_key
    restore_preset
    restore_mihomo
    restore_root_password
    printf 'Restore completed: %s -> %s\n' "$SNAPSHOT" "$TARGET"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
