#!/usr/bin/env bash
# Adjusts brightness, then pokes the quickshell OSD if it's running. If
# quickshell/qs isn't installed or isn't running, the brightness change
# still happens - the notify step is best-effort only.
set -euo pipefail

case "${1:-}" in
    up)   brightnessctl set 5%+ >/dev/null ;;
    down) brightnessctl set 5%- >/dev/null ;;
    *) echo "usage: osd-brightness.sh up|down" >&2; exit 1 ;;
esac

cur="$(brightnessctl get 2>/dev/null || echo 0)"
max="$(brightnessctl max 2>/dev/null || echo 1)"
level="$(awk -v c="$cur" -v m="$max" 'BEGIN { printf "%.2f", (m > 0 ? c/m : 0) }')"

if command -v qs >/dev/null 2>&1; then
    qs ipc call osd show brightness "$level" >/dev/null 2>&1 || true
fi
