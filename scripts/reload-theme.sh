#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  reload-theme.sh
#  Reads ~/.config/hypr/colors.conf (single source of truth) and
#  regenerates the color files consumed by waybar, rofi, kitty and
#  dunst, then reloads every running app so the new palette shows
#  up live. Run this after editing colors.conf.
# ══════════════════════════════════════════════════════════════
set -euo pipefail

CONF_DIR="$HOME/.config"
COLORS_FILE="$CONF_DIR/hypr/colors.conf"

if [[ ! -f "$COLORS_FILE" ]]; then
    echo "Could not find $COLORS_FILE" >&2
    exit 1
fi

# Pull "$name = 0xAARRGGBB" pairs into a bash assoc array
declare -A C
while IFS= read -r line; do
    [[ "$line" =~ ^\$([a-zA-Z_]+)[[:space:]]*=[[:space:]]*0x([0-9a-fA-F]{8}) ]] || continue
    name="${BASH_REMATCH[1]}"
    argb="${BASH_REMATCH[2]}"
    # strip alpha (first 2 chars) -> #RRGGBB
    C[$name]="#${argb:2}"
done < "$COLORS_FILE"

bg="${C[background]:-#000000}"
fg="${C[foreground]:-#FFFFFF}"
accent="${C[accent]:-#FFFFFF}"
muted="${C[muted]:-#808080}"
surface="${C[surface]:-#0D0D0D}"
border="${C[border_inactive]:-#2B2B2B}"

# Pull plain decimal "$name = 0.NN" opacity values (separate from the
# 0xAARRGGBB color pairs above)
declare -A O
while IFS= read -r line; do
    [[ "$line" =~ ^\$([a-zA-Z_]+)[[:space:]]*=[[:space:]]*([0-9]*\.?[0-9]+)[[:space:]]*(\#.*)?$ ]] || continue
    O[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
done < "$COLORS_FILE"

kitty_opacity="${O[kitty_opacity]:-0.95}"
bar_opacity="${O[bar_opacity]:-1.0}"

echo "Applying palette:"
echo "  background = $bg"
echo "  foreground = $fg"
echo "  accent     = $accent"
echo "  kitty_opacity = $kitty_opacity"
echo "  bar_opacity   = $bar_opacity"

# Convert #RRGGBB -> "r, g, b" decimal for rgba() literals
to_rgb() {
    local hex="${1#\#}"
    echo "$((16#${hex:0:2})), $((16#${hex:2:2})), $((16#${hex:4:2}))"
}
surface_rgb="$(to_rgb "$surface")"

# ── Waybar ──────────────────────────────────────────────
# surface uses rgba() (not @define-color surface #hex) so bar_opacity
# actually has an effect - GTK CSS ignores alpha on plain hex literals
# fed through @define-color otherwise.
mkdir -p "$CONF_DIR/waybar"
cat > "$CONF_DIR/waybar/colors.css" <<EOF
@define-color background $bg;
@define-color foreground $fg;
@define-color accent $accent;
@define-color muted $muted;
@define-color surface rgba($surface_rgb, $bar_opacity);
@define-color border_inactive $border;
EOF

# ── Rofi ────────────────────────────────────────────────
ROFI_CONF="$CONF_DIR/rofi/config.rasi"
if [[ -f "$ROFI_CONF" ]]; then
    tmp="$(mktemp)"
    awk -v bg="$bg" -v fg="$fg" -v accent="$accent" -v muted="$muted" -v surface="$surface" -v border="$border" '
        /BEGIN-GENERATED-COLORS/ { inblock=1 }
        inblock && /^\s*background:/  { sub(/background:.*/,  "background: " bg ";"); }
        inblock && /^\s*foreground:/  { sub(/foreground:.*/,  "foreground: " fg ";"); }
        inblock && /^\s*accent:/      { sub(/accent:.*/,      "accent: " accent ";"); }
        inblock && /^\s*muted:/       { sub(/muted:.*/,       "muted: " muted ";"); }
        inblock && /^\s*surface:/     { sub(/surface:.*/,     "surface: " surface ";"); }
        inblock && /^\s*border-col:/  { sub(/border-col:.*/,  "border-col: " border ";"); }
        /END-GENERATED-COLORS/ { inblock=0 }
        { print }
    ' "$ROFI_CONF" > "$tmp"
    mv "$tmp" "$ROFI_CONF"
fi

# ── Kitty ───────────────────────────────────────────────
mkdir -p "$CONF_DIR/kitty"
cat > "$CONF_DIR/kitty/colors.conf" <<EOF
foreground            $fg
background            $bg
cursor                $fg
cursor_text_color     $bg
selection_foreground  $bg
selection_background  $fg

url_color             $accent

active_border_color   $accent
inactive_border_color $border

active_tab_foreground   $bg
active_tab_background   $fg
inactive_tab_foreground $muted
inactive_tab_background $surface

# black / white 16-color palette
color0  $bg
color8  $muted
color1  $fg
color9  $fg
color2  $fg
color10 $fg
color3  $fg
color11 $fg
color4  $fg
color12 $fg
color5  $fg
color13 $fg
color6  $fg
color14 $fg
color7  $fg
color15 $fg
EOF

# ── Kitty opacity ───────────────────────────────────────
KITTY_CONF="$CONF_DIR/kitty/kitty.conf"
if [[ -f "$KITTY_CONF" ]]; then
    tmp="$(mktemp)"
    sed -E "s/^background_opacity[[:space:]]+.*/background_opacity   $kitty_opacity/" "$KITTY_CONF" > "$tmp"
    mv "$tmp" "$KITTY_CONF"
fi

# ── Dunst ───────────────────────────────────────────────
DUNSTRC="$CONF_DIR/dunst/dunstrc"
if [[ -f "$DUNSTRC" ]]; then
    tmp="$(mktemp)"
    awk -v bg="$bg" -v fg="$fg" '
        /# BEGIN-GENERATED-COLORS/ { inblock=1 }
        inblock && /background =/ { sub(/background = ".*"/, "background = \"" bg "\""); }
        inblock && /foreground =/ { sub(/foreground = ".*"/, "foreground = \"" fg "\""); }
        /# END-GENERATED-COLORS/ { inblock=0 }
        { print }
    ' "$DUNSTRC" > "$tmp"
    mv "$tmp" "$DUNSTRC"
fi

# ── Quickshell (OSD + Control Center) ───────────────────
QS_THEME="$CONF_DIR/quickshell/Theme.qml"
if [[ -f "$QS_THEME" ]]; then
    tmp="$(mktemp)"
    awk -v bg="$bg" -v fg="$fg" -v accent="$accent" -v muted="$muted" -v surface="$surface" -v border="$border" '
        /BEGIN-GENERATED-COLORS/ { inblock=1 }
        inblock && /property color background:/ { sub(/"#[0-9A-Fa-f]+"/, "\"" bg "\""); }
        inblock && /property color foreground:/ { sub(/"#[0-9A-Fa-f]+"/, "\"" fg "\""); }
        inblock && /property color accent:/     { sub(/"#[0-9A-Fa-f]+"/, "\"" accent "\""); }
        inblock && /property color muted:/      { sub(/"#[0-9A-Fa-f]+"/, "\"" muted "\""); }
        inblock && /property color surface:/    { sub(/"#[0-9A-Fa-f]+"/, "\"" surface "\""); }
        inblock && /property color border:/     { sub(/"#[0-9A-Fa-f]+"/, "\"" border "\""); }
        /END-GENERATED-COLORS/ { inblock=0 }
        { print }
    ' "$QS_THEME" > "$tmp"
    mv "$tmp" "$QS_THEME"
fi

# ── Reload running apps ─────────────────────────────────
pkill -SIGUSR2 waybar 2>/dev/null || true
command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
command -v dunst >/dev/null && killall dunst 2>/dev/null && (dunst &) || true
# Quickshell hot-reloads QML on file save on its own - no restart needed.

echo "Theme reloaded."
