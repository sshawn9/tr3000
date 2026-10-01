#!/usr/bin/env bash
set -euo pipefail
umask 077

TARGET=${1:-root@10.0.0.1}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mkdir -p -- "$SCRIPT_DIR/snapshots"
SNAPSHOT="$SCRIPT_DIR/snapshots/$(date +%Y-%m-%d_%H%M%S)"
mkdir -- "$SNAPSHOT"

backup_preset() {
    local exists
    exists=$(ssh -T -- "$TARGET" '[ -e /etc/preset.d ] && echo yes || echo no') || return
    [[ "$exists" == yes ]] || { printf 'Skipping missing /etc/preset.d\n' >&2; return 0; }
    rsync -aR -e ssh -- "${TARGET}:/etc/preset.d/" "$SNAPSHOT/"
}

backup_mihomo() {
    local exists
    exists=$(ssh -T -- "$TARGET" '[ -e /etc/mihomo ] && echo yes || echo no') || return
    [[ "$exists" == yes ]] || { printf 'Skipping missing /etc/mihomo\n' >&2; return 0; }
    rsync -aR -e ssh -- "${TARGET}:/etc/mihomo/" "$SNAPSHOT/"
}

backup_root_password() {
    local exists
    exists=$(ssh -T -- "$TARGET" '[ -e /etc/shadow ] && echo yes || echo no') || return
    [[ "$exists" == yes ]] || { printf 'Skipping missing /etc/shadow\n' >&2; return 0; }
    rsync -aR -e ssh -- "${TARGET}:/etc/shadow" "$SNAPSHOT/"
}

main() {
    backup_preset
    backup_mihomo
    backup_root_password
    printf 'Backup completed: %s\n' "$SNAPSHOT"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
