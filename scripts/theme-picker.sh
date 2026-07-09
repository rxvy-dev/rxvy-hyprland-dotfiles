#!/usr/bin/env bash
# Visual theme picker. Lists every preset in hypr/themes/ as a rofi menu
# with a small color swatch next to each name, and applies your pick to
# every app instantly via reload-theme.sh - no manually editing
# colors.conf's hex values required. SUPER+T, or the THEME button in the
# Control Center (quickshell, SUPER+A). Each preset can also name a
# companion WALLPAPER, applied at the same time (lock screen included).
#
# Add your own theme: drop a new file in hypr/themes/ with the same
# NAME/WALLPAPER/BACKGROUND/FOREGROUND/ACCENT/MUTED/SURFACE/BORDER fields
# as the existing ones (0xAARRGGBB hex, same format as colors.conf) - it
# shows up in the menu automatically, nothing else to register.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_wallpaper-common.sh"

THEMES_DIR="$HOME/.config/hypr/themes"
COLORS_FILE="$HOME/.config/hypr/colors.conf"
WALLPAPERS_DIR="$HOME/.config/hypr/wallpapers"

if [[ ! -d "$THEMES_DIR" ]]; then
    notify-send "No themes found in $THEMES_DIR" 2>/dev/null || echo "No themes found in $THEMES_DIR"
    exit 1
fi

mapfile -t THEME_FILES < <(find "$THEMES_DIR" -maxdepth 1 -type f -name "*.conf" | sort)

if [[ ${#THEME_FILES[@]} -eq 0 ]]; then
    notify-send "No presets in $THEMES_DIR" 2>/dev/null || echo "No presets found"
    exit 1
fi

# rofi's -markup-rows renders each row as Pango markup. Any label
# containing a raw &, <, or > (e.g. "Classic B&W") breaks that row's
# markup parsing - at best it renders wrong, at worst it can desync which
# row index rofi reports from the file this script thinks that index
# means, silently applying the WRONG theme. Escape before embedding.
escape_markup() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

# Build one "swatch  Name" row per preset, tracking which file each row
# index maps back to (rofi -format i returns the row index of your pick).
rows=""
declare -A ROW_TO_FILE
i=0
for f in "${THEME_FILES[@]}"; do
    NAME=""
    ACCENT=""
    # shellcheck disable=SC1090
    source "$f"
    label="$(escape_markup "${NAME:-$(basename "$f" .conf)}")"
    swatch="#${ACCENT: -6}"
    rows+="<span foreground='${swatch}'>████</span>  ${label}\n"
    ROW_TO_FILE[$i]="$f"
    i=$((i + 1))
done

chosen_idx="$(printf "%b" "$rows" | rofi -dmenu -i -markup-rows -format i -p "theme" || true)"
[[ -z "$chosen_idx" ]] && exit 0

src="${ROW_TO_FILE[$chosen_idx]:-}"
[[ -n "$src" && -f "$src" ]] || exit 0

NAME=""; WALLPAPER=""; BACKGROUND=""; FOREGROUND=""; ACCENT=""; MUTED=""; SURFACE=""; BORDER=""
# shellcheck disable=SC1090
source "$src"

# Only the 6 core palette lines get touched - comments, opacity, and the
# derived gradient-border lines in colors.conf are left exactly as they
# were, so switching themes never clobbers your opacity settings.
tmp="$(mktemp)"
awk -v bg="$BACKGROUND" -v fg="$FOREGROUND" -v ac="$ACCENT" -v mu="$MUTED" -v su="$SURFACE" -v bo="$BORDER" '
    /^\$background[[:space:]]*=/      { sub(/0x[0-9A-Fa-f]{8}/, bg) }
    /^\$foreground[[:space:]]*=/      { sub(/0x[0-9A-Fa-f]{8}/, fg) }
    /^\$accent[[:space:]]*=/          { sub(/0x[0-9A-Fa-f]{8}/, ac) }
    /^\$muted[[:space:]]*=/           { sub(/0x[0-9A-Fa-f]{8}/, mu) }
    /^\$surface[[:space:]]*=/         { sub(/0x[0-9A-Fa-f]{8}/, su) }
    /^\$border_inactive[[:space:]]*=/ { sub(/0x[0-9A-Fa-f]{8}/, bo) }
    { print }
' "$COLORS_FILE" > "$tmp"
mv "$tmp" "$COLORS_FILE"

~/.config/hypr-scripts/reload-theme.sh >/dev/null 2>&1 || true

if [[ -n "$WALLPAPER" && -f "$WALLPAPERS_DIR/$WALLPAPER" ]]; then
    apply_wallpaper "$WALLPAPERS_DIR/$WALLPAPER"
fi

notify-send "Theme" "${NAME:-$(basename "$src" .conf)} applied" 2>/dev/null || true
