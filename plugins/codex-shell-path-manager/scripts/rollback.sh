#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ps_script="$script_dir/rollback.ps1"
if command -v cygpath >/dev/null 2>&1; then
  ps_script="$(cygpath -w "$ps_script")"
fi

exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps_script" "$@"
