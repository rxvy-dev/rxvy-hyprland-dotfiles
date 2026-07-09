#!/usr/bin/env bash
# Shows every preset in hypr/wallpapers/ as an actual thumbnail in rofi
# (rofi's dmenu icon protocol: "Name\0icon\x1f/path"), so you pick by
# sight instead of clicking WALL repeatedly. Bound to right-click on the
# WALL button in waybar, and to SUPER+W.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_wallpaper-common.sh"

mapfile -t WALLS < <(list_wallpapers)

if [[ ${#WALLS[@]} -eq 0 ]]; then
    notify-send "No wallpapers found in ~/.config/hypr/wallpapers" 2>/dev/null || echo "No wallpapers found"
    exit 1
fi

entries=""
for w in "${WALLS[@]}"; do
    name="$(basename "$w")"
    name="${name%.*}"
    entries+="${name}\0icon\x1f${w}\n"
done

chosen_name="$(printf "%b" "$entries" | rofi -dmenu -i -show-icons -p "wallpaper" \
    -theme-str 'window {width: 40%;} listview {columns: 3; lines: 3;} element {orientation: vertical;} element-icon {size: 160px;}' \
    || true)"

[[ -z "$chosen_name" ]] && exit 0

for w in "${WALLS[@]}"; do
    base="$(basename "$w")"
    if [[ "${base%.*}" == "$chosen_name" ]]; then
        apply_wallpaper "$w"
        exit 0
    fi
done
