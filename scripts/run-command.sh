#!/usr/bin/env bash
# Bound to the RUN button in waybar (custom/exec module).
# Prompts for a shell command with rofi, then runs it. If the command
# looks like a known TUI/CLI program (htop, vim, lazygit, python3...) it
# gets opened inside a new kitty window so its terminal UI is actually
# visible; anything else is treated as a normal GUI app and launched
# detached, same as a launcher entry.
#
# Add your own programs to TUI_APPS below (space-separated, program
# name only - not the full command) if something you run often keeps
# launching headless instead of in a terminal.
set -euo pipefail

TUI_APPS=(
    htop btop top nmon iotop iftop nethogs glances gotop bashtop bpytop
    vim nvim vi nano emacs
    less more man
    ranger lf yazi nnn mc
    ncdu duf dust
    tmux screen zellij
    lazygit lazydocker gitui tig
    nmtui bluetuith impala
    cmus ncmpcpp cava
    irssi weechat aerc neomutt mutt
    k9s ktop
    python3 python ipython node irb
    ssh mosh
)

cmd="$(rofi -dmenu -p 'run>' -theme-str 'window {width: 32%;} listview {lines: 0;}' </dev/null || true)"
[[ -z "${cmd// /}" ]] && exit 0

prog="$(awk '{print $1}' <<< "$cmd")"

is_tui=false
for t in "${TUI_APPS[@]}"; do
    if [[ "$prog" == "$t" ]]; then
        is_tui=true
        break
    fi
done

if $is_tui; then
    kitty --title "$cmd" -e sh -c "$cmd"
else
    setsid -f sh -c "$cmd" >/dev/null 2>&1
fi
