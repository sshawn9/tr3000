#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

while IFS= read -r -d '' script; do
    bash "$script"
done < <(find . -mindepth 2 -type f -name prepare.sh -print0)
