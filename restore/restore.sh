#!/usr/bin/env bash
set -euo pipefail
umask 077

SNAPSHOT=$(cd -- "${1:?用法：restore.sh 备份目录 [SSH目标]}" && pwd -P)
TARGET=${2:-root@10.0.0.1}

setup_ssh_key() {
    ssh-copy-id -- "$TARGET"
}

restore_preset() {
    rsync -a --chown=root:root -e ssh -- "$SNAPSHOT/preset.d/" "${TARGET}:/etc/preset.d/"
}

restore_mihomo() {
    rsync -a --chown=root:root -e ssh -- "$SNAPSHOT/mihomo/" "${TARGET}:/etc/mihomo/"
}

restore_root_password() {
    local entry

    entry=$(awk -F: '$1 == "root" { print $1 ":" $2; found = 1; exit } END { if (!found) exit 1 }' "$SNAPSHOT/shadow")
    printf '%s\n' "$entry" | ssh -T -- "$TARGET" 'chpasswd -e'
}

main() {
    setup_ssh_key
    restore_preset
    restore_mihomo
    restore_root_password
    printf '恢复完成：%s → %s\n' "$SNAPSHOT" "$TARGET"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
