#!/usr/bin/env bash
# Thin wrapper around apply_wallpaper() so QML (which can only spawn plain
# commands, not source bash functions) can reuse the exact same logic as
# cycle-wallpaper.sh and pick-wallpaper.sh - keeps hyprpaper, hyprlock, and
# the "last used" cache all in sync from every entry point.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_wallpaper-common.sh"

if [[ $# -ne 1 ]]; then
    echo "usage: apply-wallpaper.sh <absolute-path-to-image>" >&2
    exit 1
fi

apply_wallpaper "$1"
