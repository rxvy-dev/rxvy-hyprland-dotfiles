#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  install.sh — symlink this repo's configs into ~/.config
#  Arch Linux / Hyprland
# ══════════════════════════════════════════════════════════════
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

PACKAGES=(
    hyprland waybar rofi kitty dunst hyprpaper hyprlock swayidle
    wl-clipboard cliphist grim slurp brightnessctl
    pipewire wireplumber thunar polkit-kde-agent wlogout
    ttf-jetbrains-mono-nerd papirus-icon-theme
)
# AUR-only - a plain `pacman -S` fails on the WHOLE batch if any package in
# it doesn't exist in the official repos, so these are installed separately
# and only via yay (or noted for manual install if yay isn't present).
AUR_PACKAGES=(
    grimblast quickshell
)

echo "== Hyprland black & white dotfiles installer =="
echo

read -rp "Install packages with pacman/yay now? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    if command -v yay >/dev/null; then
        yay -S --needed "${PACKAGES[@]}" "${AUR_PACKAGES[@]}"
    else
        sudo pacman -S --needed "${PACKAGES[@]}"
        echo "Note: ${AUR_PACKAGES[*]} are AUR-only and were skipped (no yay found)."
        echo "Install an AUR helper first, or build these manually:"
        for p in "${AUR_PACKAGES[@]}"; do echo "  $p"; done
    fi
fi

mkdir -p "$BACKUP_DIR"

link() {
    local src="$1" dest="$2"
    if [[ -e "$dest" || -L "$dest" ]]; then
        mkdir -p "$(dirname "$BACKUP_DIR/${dest#$HOME/}")"
        mv "$dest" "$BACKUP_DIR/${dest#$HOME/}"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    echo "linked $dest -> $src"
}

link "$REPO_DIR/hypr"   "$CONF_DIR/hypr"
link "$REPO_DIR/waybar" "$CONF_DIR/waybar"
link "$REPO_DIR/rofi"   "$CONF_DIR/rofi"
link "$REPO_DIR/kitty"  "$CONF_DIR/kitty"
link "$REPO_DIR/dunst"  "$CONF_DIR/dunst"
link "$REPO_DIR/wlogout" "$CONF_DIR/wlogout"
link "$REPO_DIR/scripts" "$CONF_DIR/hypr-scripts"
link "$REPO_DIR/quickshell" "$CONF_DIR/quickshell"

chmod +x "$REPO_DIR/scripts/reload-theme.sh" "$REPO_DIR/scripts/cycle-wallpaper.sh" \
         "$REPO_DIR/scripts/pick-wallpaper.sh" "$REPO_DIR/scripts/_wallpaper-common.sh" \
         "$REPO_DIR/scripts/run-command.sh" "$REPO_DIR/scripts/doctor.sh" \
         "$REPO_DIR/scripts/osd-volume.sh" "$REPO_DIR/scripts/osd-brightness.sh" \
         "$REPO_DIR/scripts/apply-wallpaper.sh" "$REPO_DIR/scripts/theme-picker.sh" \
         "$REPO_DIR/scripts/apply-monitor-layout.sh"
"$REPO_DIR/scripts/reload-theme.sh" || true

echo
echo "Done. Anything that existed before was backed up to: $BACKUP_DIR"
echo "Log out and select Hyprland from your display manager, or run 'Hyprland' from a TTY."
echo "Edit hypr/colors.conf then run ~/.config/hypr-scripts/reload-theme.sh any time you want a new palette."
echo "If the bar (or anything else) doesn't show up after logging into Hyprland, run:"
echo "  ~/.config/hypr-scripts/doctor.sh"
echo "or press SUPER+SHIFT+D once you're in the session."
