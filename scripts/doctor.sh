#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  doctor.sh — checks the usual suspects when something in this
#  setup (most often the bar) silently isn't there.
#  Run it, read the ✗ lines, that's almost always the fix.
# ══════════════════════════════════════════════════════════════
set -uo pipefail

pass() { echo "  OK    $1"; }
fail() { echo "  FAIL  $1"; }
warn() { echo "  WARN  $1"; }

echo "== hyprland-dots doctor =="
echo

# ── Are we actually inside a Hyprland session? ─────────────
echo "-- Session --"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    pass "Running inside a Hyprland session"
else
    fail "HYPRLAND_INSTANCE_SIGNATURE is not set — this doesn't look like a running Hyprland session. Run this script FROM INSIDE Hyprland (e.g. from a kitty window on the desktop), not from a plain TTY / SSH session."
fi
echo

# ── Required binaries ───────────────────────────────────────
echo "-- Binaries --"
for bin in hyprland waybar rofi kitty dunst hyprpaper hyprlock wlogout swayidle; do
    if command -v "$bin" >/dev/null 2>&1; then
        pass "$bin found ($(command -v "$bin"))"
    else
        fail "$bin not found on PATH — install it (see install.sh's package list)"
    fi
done
if command -v qs >/dev/null 2>&1; then
    pass "qs (quickshell) found ($(command -v qs))"
    if pgrep -x qs >/dev/null 2>&1; then
        pass "quickshell process is running (OSD + Control Center + Monitor Manager should work)"
    else
        warn "qs is installed but no quickshell process is running — SUPER+A, SUPER+M, and the volume/brightness OSD won't respond."
    fi
    QS_LOG="$HOME/.cache/qs.log"
    if [[ -f "$QS_LOG" ]]; then
        echo "  Last 10 lines of $QS_LOG:"
        tail -n 10 "$QS_LOG" | sed 's/^/    /'
        if tail -n 30 "$QS_LOG" | grep -qiE "error|fatal|exception"; then
            fail "the log above has error/fatal lines — that's likely why quickshell features aren't responding"
        fi
    else
        warn "no log yet at $QS_LOG — check hyprland.conf's exec-once wrapper for qs ran (or just log out/in once after updating to it)"
    fi
else
    warn "qs (quickshell) not found — this is OPTIONAL. The OSD, Control Center (SUPER+A), and Monitor Manager (SUPER+M) won't work, but everything else (bar, launcher, terminal) is unaffected. Install via an AUR helper: yay -S quickshell"
fi
echo

# ── Font ─────────────────────────────────────────────────────
echo "-- Font --"
if command -v fc-list >/dev/null 2>&1; then
    if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
        pass "JetBrainsMono Nerd Font is installed"
    else
        warn "JetBrainsMono Nerd Font not found by fontconfig. Bar/rofi/kitty text and icons will fall back to a default font and glyphs like the icons in wlogout/tray may render as boxes. Install ttf-jetbrains-mono-nerd."
    fi
else
    warn "fc-list not found, can't check installed fonts (install fontconfig)"
fi
echo

# ── Symlinks from install.sh ────────────────────────────────
echo "-- Config symlinks (from install.sh) --"
for pair in "hypr" "waybar" "rofi" "kitty" "dunst" "wlogout" "hypr-scripts" "quickshell"; do
    target="$HOME/.config/$pair"
    if [[ -L "$target" ]]; then
        dest="$(readlink -f "$target")"
        if [[ -e "$target" ]]; then
            pass "~/.config/$pair -> $dest"
        else
            fail "~/.config/$pair is a symlink but points to a MISSING path: $dest (repo moved/deleted? re-run install.sh)"
        fi
    elif [[ -e "$target" ]]; then
        warn "~/.config/$pair exists but is a real file/dir, not a symlink to this repo — install.sh wasn't run here, or something else wrote to it"
    else
        fail "~/.config/$pair doesn't exist at all — run install.sh"
    fi
done
echo

# ── Theme presets ────────────────────────────────────────────
echo "-- Theme presets --"
THEMES_DIR="$HOME/.config/hypr/themes"
if [[ -d "$THEMES_DIR" ]]; then
    count="$(find "$THEMES_DIR" -maxdepth 1 -type f -name "*.conf" | wc -l)"
    if [[ "$count" -gt 0 ]]; then
        pass "$count theme preset(s) found — SUPER+T / THEME button should list them"
    else
        fail "$THEMES_DIR exists but has no .conf presets in it"
    fi
else
    fail "$THEMES_DIR not found — SUPER+T will report no themes"
fi
echo

# ── Monitor config ───────────────────────────────────────────
echo "-- Monitor config --"
MON_CONF="$HOME/.config/hypr/monitors.conf"
if [[ -f "$MON_CONF" ]]; then
    pass "monitors.conf found (sourced from hyprland.conf)"
else
    fail "$MON_CONF not found — hyprland.conf's 'source' line for it will fail to parse. Re-run install.sh."
fi
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    mon_count="$(hyprctl monitors -j 2>/dev/null | grep -o '"name":' | wc -l)"
    if [[ "$mon_count" -gt 0 ]]; then
        pass "hyprctl reports $mon_count connected monitor(s) — SUPER+M should list them"
    else
        warn "hyprctl monitors -j returned no monitors — SUPER+M will show an empty panel"
    fi
fi
echo

# ── Waybar config validity ──────────────────────────────────
echo "-- Waybar config --"
WB_CONF="$HOME/.config/waybar/config.jsonc"
if [[ -f "$WB_CONF" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 - "$WB_CONF" <<'PYEOF'
import json, sys
path = sys.argv[1]
text = open(path).read()
out, in_str, esc = [], False, False
i = 0
while i < len(text):
    c = text[i]
    if in_str:
        out.append(c)
        if esc: esc = False
        elif c == '\\': esc = True
        elif c == '"': in_str = False
        i += 1; continue
    if c == '"':
        in_str = True; out.append(c); i += 1; continue
    if c == '/' and i+1 < len(text) and text[i+1] == '/':
        while i < len(text) and text[i] != '\n': i += 1
        continue
    out.append(c); i += 1
try:
    json.loads(''.join(out))
    sys.exit(0)
except Exception as e:
    print(e); sys.exit(1)
PYEOF
        then
            pass "config.jsonc parses as valid JSON"
        else
            fail "config.jsonc has a JSON syntax error (see above) — this alone is enough to make the whole bar fail to start"
        fi
    else
        warn "python3 not found, skipping JSON validation"
    fi
else
    fail "$WB_CONF not found"
fi
echo

# ── Is waybar actually running? ─────────────────────────────
echo "-- Waybar process --"
if pgrep -x waybar >/dev/null 2>&1; then
    pass "waybar process is running"
else
    fail "no waybar process running right now"
fi
echo

# ── The log (this is usually the real answer) ───────────────
echo "-- Waybar log (~/.cache/waybar.log) --"
LOG="$HOME/.cache/waybar.log"
if [[ -f "$LOG" ]]; then
    echo "  Last 15 lines:"
    tail -n 15 "$LOG" | sed 's/^/    /'
    if tail -n 30 "$LOG" | grep -qiE "error|fatal|exception|failed to parse"; then
        fail "the log contains error/fatal/exception lines above — that's almost certainly why the bar isn't showing"
    fi
else
    warn "no log file yet at $LOG — waybar has never been launched via the exec-once wrapper in hyprland.conf. Check hyprland.conf's exec-once lines are intact."
fi
echo

echo "== done =="
echo "If everything above is OK but the bar still isn't visible, run"
echo "'waybar' directly in a terminal (not via the restart-loop) and read"
echo "whatever it prints — that's the unfiltered error."
