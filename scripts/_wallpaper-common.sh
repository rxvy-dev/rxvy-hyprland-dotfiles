#!/usr/bin/env bash
# Sourced by cycle-wallpaper.sh and pick-wallpaper.sh. Not meant to be run
# directly. Applying a wallpaper here means three things happen together:
#   1. hyprpaper switches the live desktop wallpaper (instant - already preloaded)
#   2. hyprlock.conf's background path is rewritten to match, so the lock
#      screen never falls back to a stale/default wallpaper
#   3. the choice is cached, so hyprland.conf's exec-once can restore it
#      on the next login instead of always booting into "mountains"

apply_wallpaper() {
    local wall="$1"   # absolute path, e.g. $HOME/.config/hypr/wallpapers/grid.png

    if [[ ! -f "$wall" ]]; then
        echo "apply_wallpaper: no such file: $wall" >&2
        return 1
    fi

    hyprctl hyprpaper wallpaper ",$wall" >/dev/null 2>&1 || true

    local hyprlock_conf="$HOME/.config/hypr/hyprlock.conf"
    if [[ -f "$hyprlock_conf" ]]; then
        local tmp
        tmp="$(mktemp)"
        # Only touches the `path = ...` line inside the background {} block
        awk -v wall="$wall" '
            /^background[[:space:]]*\{/ { inbg=1 }
            inbg && /^\s*path[[:space:]]*=/ { print "    path = " wall; next }
            /^\}/ { inbg=0 }
            { print }
        ' "$hyprlock_conf" > "$tmp"
        mv "$tmp" "$hyprlock_conf"
    fi

    mkdir -p "$HOME/.cache"
    echo "$wall" > "$HOME/.cache/hypr-current-wallpaper"

    notify-send "Wallpaper" "$(basename "$wall")" 2>/dev/null || true
}

list_wallpapers() {
    find "$HOME/.config/hypr/wallpapers" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" \) | sort
}
