#!/usr/bin/env bash
# Remove Prism and (optionally) restore the configs it backed up. Packages are left installed.
set -euo pipefail
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
read -r -p "Remove Prism configs, scripts and themes? [y/N] " a
[[ "${a:-n}" =~ ^[Yy] ]] || exit 0

for d in hypr waybar kitty rofi mako fastfetch; do
    if [ -f "$CONFIG/$d/.prism" ]; then
        # keep the user's own custom.* files next to the backup
        mkdir -p "$CONFIG/prism/kept-custom/$d"
        find "$CONFIG/$d" -maxdepth 1 -name 'custom.*' -exec cp {} "$CONFIG/prism/kept-custom/$d/" \; 2>/dev/null || true
        rm -rf "${CONFIG:?}/${d:?}"
        echo "removed ~/.config/$d"
    fi
done
for f in prism prism-settings prism-autostart prism-launcher prism-power prism-screenshot prism-clipboard \
         prism-theme-menu prism-keybinds prism-osd; do
    rm -f "$HOME/.local/bin/$f"
done
rm -rf "$DATA/prism" "$DATA/applications/prism-settings.desktop"
echo "removed scripts and themes"

latest=$(ls -d "$CONFIG"/prism-backup-* 2>/dev/null | sort | tail -1 || true)
if [ -n "$latest" ]; then
    read -r -p "Restore your old configs from ${latest/#$HOME/~}? [Y/n] " a
    if [[ "${a:-y}" =~ ^[Yy] ]]; then
        for d in "$latest"/*; do
            n=$(basename "$d")
            [ -e "$CONFIG/$n" ] && { echo "skip $n (already exists)"; continue; }
            mv "$d" "$CONFIG/$n" && echo "restored $n"
        done
    fi
fi
echo "Settings and your custom wallpapers stay in ~/.config/prism — delete it if you don't need them."
