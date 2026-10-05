#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
shopt -s nullglob

for script in */prepare.sh; do
    [[ -e "${script%/prepare.sh}/.skip" ]] && continue
    bash "$script"
done
