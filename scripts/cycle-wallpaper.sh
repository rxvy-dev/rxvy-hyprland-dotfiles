#!/usr/bin/env bash
# Cycles through the preset wallpapers in hypr/wallpapers/ (all already
# preloaded by hyprpaper, so this switch is instant). Bound to the WALL
# button in waybar (left-click); right-click opens the visual picker
# instead (pick-wallpaper.sh). Safe to run manually too.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_wallpaper-common.sh"

STATE_FILE="$HOME/.cache/hypr-wallpaper-index"
mkdir -p "$HOME/.cache"

mapfile -t WALLS < <(list_wallpapers)

if [[ ${#WALLS[@]} -eq 0 ]]; then
    notify-send "No wallpapers found in ~/.config/hypr/wallpapers" 2>/dev/null || echo "No wallpapers found"
    exit 1
fi

idx=0
[[ -f "$STATE_FILE" ]] && idx="$(cat "$STATE_FILE")"
idx=$(( (idx + 1) % ${#WALLS[@]} ))
echo "$idx" > "$STATE_FILE"

apply_wallpaper "${WALLS[$idx]}"
