#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-root@10.0.0.1}

set_root_password() {
    ssh -t -- "$TARGET" 'passwd root'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set_root_password
fi
