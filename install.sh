#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  PRISM — Hyprland rice installer for Arch Linux                  ║
# ║  ./install.sh [-y] [--theme <id>] [--no-packages] [--help]       ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/prism-backup-$STAMP"

YES=0; NOPKG=0; THEME=""
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) YES=1 ;;
        --no-packages) NOPKG=1 ;;
        --theme) THEME="${2:-}"; shift ;;
        -h|--help)
            sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
            echo
            echo "  -y, --yes        don't ask questions, use defaults"
            echo "  --theme <id>     starting theme (see share/themes/)"
            echo "  --no-packages    only copy configs, don't touch pacman"
            exit 0 ;;
        *) echo "unknown option: $1 (try --help)"; exit 1 ;;
    esac
    shift
done

# ── pretty output ──────────────────────────────────────────────────
if [ -t 1 ]; then
    R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; M=$'\e[35m'; C=$'\e[36m'; W=$'\e[1m'; N=$'\e[0m'
else R=; G=; Y=; B=; M=; C=; W=; N=; fi
step() { printf '\n%s==>%s %s%s%s\n' "$M" "$N" "$W" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
ask()  { # ask "question" default(y/n)
    local q="$1" d="${2:-y}" a
    [ "$YES" = 1 ] && { [ "$d" = y ]; return; }
    local hint="[Y/n]"; [ "$d" = n ] && hint="[y/N]"
    read -r -p "  ${C}?${N} $q $hint " a || true
    a="${a:-$d}"
    [[ "$a" =~ ^[Yy] ]]
}

cat <<EOF
${M}
        /\\
       /  \\      ${W}P R I S M${N}${M}
      / /\\ \\     ${N}a Hyprland rice — retro & modern themes${M}
     / /__\\ \\    ${N}kitty · waybar · rofi · fastfetch · settings app${M}
    /________\\
${N}
EOF

# ── sanity checks ──────────────────────────────────────────────────
[ "$EUID" -eq 0 ] && [ -z "${PRISM_ALLOW_ROOT:-}" ] && die "Run this as your normal user, not root. It will use sudo when needed."
[ -d "$HERE/config" ] && [ -d "$HERE/share/themes" ] || die "Run install.sh from inside the extracted prism folder."
if [ "$NOPKG" = 0 ]; then
    command -v pacman >/dev/null || die "pacman not found — this installer is for Arch Linux (use --no-packages elsewhere)."
fi

if [ -n "$THEME" ] && [ ! -d "$HERE/share/themes/$THEME" ]; then
    die "Unknown theme '$THEME'. Available: $(ls "$HERE/share/themes" | tr '\n' ' ')"
fi

if [ -z "$THEME" ] && [ "$YES" = 0 ] && [ ! -f "$CONFIG/prism/settings.json" ]; then
    echo
    echo "  Pick a starting theme (you can switch any time with Super+T):"
    i=1; ids=()
    for d in "$HERE"/share/themes/*/; do
        id=$(basename "$d"); ids+=("$id")
        name=$(grep '^NAME=' "$d/theme.conf" | cut -d= -f2-)
        kind=$(grep '^KIND=' "$d/theme.conf" | cut -d= -f2-)
        printf '   %s%2d%s) %-18s %s%s%s\n' "$C" "$i" "$N" "$name" "$Y" "$kind" "$N"
        i=$((i + 1))
    done
    read -r -p "  ${C}?${N} Number [default: Tokyo Night] " n || true
    if [[ "${n:-}" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#ids[@]}" ]; then
        THEME="${ids[$((n - 1))]}"
    fi
fi
THEME_GIVEN=0; [ -n "$THEME" ] && THEME_GIVEN=1
THEME="${THEME:-tokyo-night}"

# ── packages ───────────────────────────────────────────────────────
PKGS=(
  # compositor + hypr ecosystem
  hyprland hyprlock hypridle hyprsunset hyprpicker hyprpolkitagent
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland
  # shell pieces
  waybar rofi kitty fastfetch mako libnotify swaybg btop
  # screenshots + clipboard
  grim slurp swappy wl-clipboard cliphist
  # hardware keys, audio, network, bluetooth
  brightnessctl playerctl pipewire pipewire-pulse wireplumber pavucontrol
  networkmanager network-manager-applet bluez bluez-utils blueman
  # files
  thunar thunar-archive-plugin thunar-volman file-roller gvfs tumbler xdg-user-dirs xdg-utils pciutils
  # settings app + theming
  python python-gobject gtk4 libadwaita adw-gtk-theme papirus-icon-theme glib2
  # fonts
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
  ttf-terminus-nerd ttf-ibmplex-mono-nerd
)

if [ "$NOPKG" = 0 ]; then
    step "Packages"
    echo "  Prism needs about ${#PKGS[@]} packages from the official repos (already-installed ones are skipped)."
    if ask "Install them now with pacman?" y; then
        sudo -v || die "sudo is required to install packages."
        avail=(); missing=()
        for p in "${PKGS[@]}"; do
            if pacman -Si "$p" >/dev/null 2>&1; then avail+=("$p")
            elif [ "$p" = rofi ] && pacman -Si rofi-wayland >/dev/null 2>&1; then avail+=(rofi-wayland)
            else missing+=("$p"); fi
        done
        [ ${#missing[@]} -gt 0 ] && warn "Not in your repos (skipped): ${missing[*]}"
        sudo pacman -S --needed --noconfirm "${avail[@]}" || die "pacman failed — fix the error above and run again."
        ok "packages installed"

        if ! command -v firefox >/dev/null && ! command -v chromium >/dev/null && ! command -v brave >/dev/null \
           && ! command -v zen-browser >/dev/null && ask "No web browser found. Install Firefox?" y; then
            sudo pacman -S --needed --noconfirm firefox && ok "firefox installed"
        fi
    else
        warn "skipping packages — make sure everything in packages.txt is installed"
    fi
fi

# ── NVIDIA ─────────────────────────────────────────────────────────
NVIDIA=false
if command -v lspci >/dev/null && lspci | grep -qiE 'vga|3d|display' && lspci | grep -iE 'vga|3d|display' | grep -qi nvidia; then
    NVIDIA=true
    step "NVIDIA GPU detected"
    ok "Wayland env vars for NVIDIA will be enabled automatically"
    if [ "$NOPKG" = 0 ] && ! pacman -Q nvidia-utils >/dev/null 2>&1; then
        if ask "Install the open NVIDIA driver (nvidia-open-dkms, nvidia-utils, egl-wayland)?" y; then
            heads=()
            for k in /usr/lib/modules/*/pkgbase; do
                [ -f "$k" ] && heads+=("$(cat "$k")-headers")
            done
            sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver "${heads[@]}" \
                && ok "driver installed — reboot before starting Hyprland" \
                || warn "driver install failed; see the Arch wiki NVIDIA page"
        fi
    else
        ok "nvidia-utils already installed"
    fi
fi

# ── Hyprland version check ─────────────────────────────────────────
if command -v Hyprland >/dev/null; then
    ver=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [ -n "$ver" ]; then
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "$(echo "$ver" | cut -d. -f1)" = 0 ] && [ "$minor" -lt 55 ]; then
            warn "Hyprland $ver is older than 0.55 — Prism uses the Lua config format. Update with: sudo pacman -Syu"
        else
            ok "Hyprland $ver (Lua config)"
        fi
    fi
fi

# ── back up existing configs ───────────────────────────────────────
step "Backing up your current configs"
backed=0
for d in hypr waybar kitty rofi mako fastfetch; do
    if [ -e "$CONFIG/$d" ] && [ ! -f "$CONFIG/$d/.prism" ]; then
        mkdir -p "$BACKUP"
        mv "$CONFIG/$d" "$BACKUP/$d"
        ok "$d → ${BACKUP/#$HOME/~}/$d"
        backed=1
    fi
done
[ "$backed" = 0 ] && ok "nothing to back up (no configs, or already Prism)"

# ── copy files ─────────────────────────────────────────────────────
step "Installing Prism"
mkdir -p "$CONFIG" "$DATA/prism" "$BIN" "$DATA/applications" "$CONFIG/prism/wallpapers"

for d in hypr waybar kitty rofi mako fastfetch; do
    mkdir -p "$CONFIG/$d"
    [ -d "$HERE/config/$d" ] || continue
    # copy everything, but never overwrite the user's custom.* files
    (cd "$HERE/config/$d" && find . -type f) | while read -r f; do
        src="$HERE/config/$d/$f"; dst="$CONFIG/$d/$f"
        mkdir -p "$(dirname "$dst")"
        case "$(basename "$f")" in
            custom.*) [ -e "$dst" ] || cp "$src" "$dst" ;;
            *) cp "$src" "$dst" ;;
        esac
    done
    echo "installed by prism $STAMP" > "$CONFIG/$d/.prism"
done
ok "configs → ~/.config"

rm -rf "$DATA/prism/lib" "$DATA/prism/themes"
cp -r "$HERE/share/lib" "$HERE/share/themes" "$DATA/prism/"
rm -rf "$DATA/prism/lib/__pycache__"
ok "themes + engine → ${DATA/#$HOME/~}/prism"

for f in "$HERE"/bin/*; do
    [ -f "$f" ] || continue
    install -m 755 "$f" "$BIN/$(basename "$f")"
done
ok "scripts → ~/.local/bin ($(ls "$HERE/bin" | wc -l) commands)"

install -m 644 "$HERE/share/applications/prism-settings.desktop" "$DATA/applications/"
command -v update-desktop-database >/dev/null && update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
ok "Prism Settings added to your app menu"

# ── settings ───────────────────────────────────────────────────────
export PATH="$BIN:$PATH"
python3 - "$THEME" "$NVIDIA" "$THEME_GIVEN" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "prism", "lib"))
import prismlib as P
theme, nvidia = sys.argv[1], sys.argv[2] == "true"
s = P.load_settings()
fresh = not os.path.exists(P.SETTINGS_FILE)
if fresh or (sys.argv[3] == "1" and theme != s.get("theme")):
    s["theme"] = theme
    s["wallpaper"] = None
s["nvidia"] = nvidia
import shutil
if not shutil.which(s.get("browser", "firefox")):
    for b in ("firefox", "chromium", "brave", "zen-browser", "google-chrome-stable"):
        if shutil.which(b):
            s["browser"] = b
            break
P.save_settings(s)
PY
prism apply --no-reload >/dev/null && ok "theme '$(prism current)' generated" || die "theme generation failed"

[ -f "$CONFIG/hypr/custom.lua" ] || cat > "$CONFIG/hypr/custom.lua" <<'EOF'
-- Your own Hyprland tweaks. Prism never overwrites this file.
-- Examples:
-- hl.bind("SUPER + Z", hl.dsp.exec_cmd("zeditor"))
-- hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
EOF

command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update || true
fc-cache -f >/dev/null 2>&1 || true

# ── services ───────────────────────────────────────────────────────
if [ "$NOPKG" = 0 ]; then
    step "Services"
    if systemctl list-unit-files NetworkManager.service >/dev/null 2>&1 && ! systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
        if systemctl is-active --quiet iwd || systemctl is-active --quiet systemd-networkd || systemctl is-active --quiet connman; then
            warn "another network service is running — leaving NetworkManager disabled"
        elif ask "Enable NetworkManager (Wi-Fi menu in the bar)?" y; then
            sudo systemctl enable --now NetworkManager && ok "NetworkManager enabled"
        fi
    fi
    if systemctl list-unit-files bluetooth.service >/dev/null 2>&1 && ! systemctl is-enabled --quiet bluetooth 2>/dev/null; then
        ask "Enable Bluetooth?" y && sudo systemctl enable --now bluetooth && ok "bluetooth enabled" || true
    fi
fi

# ── live reload if we're already inside Hyprland ──────────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    prism apply >/dev/null 2>&1 || true
    pgrep -x waybar >/dev/null || (waybar >/dev/null 2>&1 &)
    ok "reloaded your running Hyprland session"
fi

cat <<EOF

${G}${W}  ✓ Prism is installed.${N}

  ${W}Start it:${N}   log out and pick ${C}Hyprland${N} in your login screen,
              or from a TTY run: ${C}start-hyprland${N}

  ${W}First keys:${N} ${C}Super+Return${N} terminal   ${C}Super+Space${N} apps
              ${C}Super+I${N} settings        ${C}Super+T${N} themes
              ${C}Super+F1${N} all keybinds   ${C}Super+Esc${N} power menu

  ${W}Commands:${N}   prism themes · prism theme synthwave · prism wallpaper random
EOF
[ -d "$BACKUP" ] && echo "  ${W}Backup:${N}     ${BACKUP/#$HOME/~}  (restore with ./uninstall.sh)" || true
echo
