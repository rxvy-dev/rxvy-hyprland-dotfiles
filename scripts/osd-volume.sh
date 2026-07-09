#!/usr/bin/env bash
# Adjusts volume, then pokes the quickshell OSD if it's running. If
# quickshell/qs isn't installed or isn't running, the volume change still
# happens - the notify step is best-effort only.
set -euo pipefail

case "${1:-}" in
    up)   wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
    down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    *) echo "usage: osd-volume.sh up|down|mute" >&2; exit 1 ;;
esac

raw="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.0")"
level="$(awk '{print $2}' <<< "$raw")"
[[ "$raw" == *MUTED* ]] && level=0

if command -v qs >/dev/null 2>&1; then
    qs ipc call osd show volume "$level" >/dev/null 2>&1 || true
fi
