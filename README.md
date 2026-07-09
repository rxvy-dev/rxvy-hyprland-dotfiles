## Previews

<p align="center">
  <img src="2026-07-03-024739_hyprshot.jpg" width="45%" alt="Hyprshot Preview" />
  <img src="Untitled.png" width="45%" alt="Untitled Preview" />
  <img src="power.png" width="45%" alt="power preview" />
</p>

# hyprland-dots — black & white edition

A minimal, monochrome Hyprland setup for Arch Linux with a terminal-HUD
style top bar, a command-palette-style launcher, and nine preset black &
white wallpapers — cycle through them or pick one visually by thumbnail.
Every app in this repo (Hyprland itself, Waybar, rofi, kitty, dunst) reads
its colors from a single file, so re-theming the whole desktop is a
one-file edit.

## What's included

| Component  | Purpose               |
|------------|------------------------|
| `hypr/`    | Hyprland, hyprpaper, hyprlock configs + monitors.conf + 9 preset wallpapers + 12 color-theme presets |
| `waybar/`  | Top bar — single HUD strip, uppercase labels, bracket workspaces |
| `rofi/`    | App launcher — bracket/terminal command-palette look |
| `kitty/`   | Terminal, 60% background transparency, cursor trail + eased blink animations |
| `dunst/`   | Notifications |
| `wlogout/` | Power menu (lock/logout/suspend/reboot/shutdown) |
| `quickshell/` | OSD (volume/brightness popup) + Control Center (SUPER+A) + Monitor Manager (SUPER+M) |
| `scripts/` | Theme sync + picker, wallpaper cycling + visual picker, run-command prompt, doctor |

## Requirements

Arch Linux with Hyprland 0.55+ (this repo targets the current `.conf`
syntax; see the note below if you're on an older/newer version). Install
with:

```bash
sudo pacman -S hyprland waybar rofi kitty dunst hyprpaper hyprlock swayidle \
  wl-clipboard cliphist grim slurp brightnessctl pipewire wireplumber \
  thunar polkit-kde-agent wlogout ttf-jetbrains-mono-nerd papirus-icon-theme
yay -S grimblast quickshell   # AUR-only, need an AUR helper
```

`install.sh` will offer to do this for you. `quickshell` is optional — it
only powers the OSD and Control Center (see below); everything else works
without it.

## Install

```bash
git clone https://github.com/rxvy-dev/rxvy-hyprland-dotfiles.git
cd rxvy-hyprland-dotfiles
./install.sh
```

The script symlinks each folder into `~/.config` (including `scripts/` →
`~/.config/hypr-scripts`, so buttons in the bar can find it regardless of
where you cloned the repo), backing up anything that's already there into
`~/.config-backup-<timestamp>`.

## Publishing this to GitHub

This folder is already a git repo with commits (`git log` to see them).
To push it to `github.com/rxvy-dev/rxvy-hyprland-dotfiles`:

1. Create the (empty) repo on GitHub first — go to
   [github.com/new](https://github.com/new), owner `rxvy-dev`, name
   `rxvy-hyprland-dotfiles`, and **don't** initialize it with a README/
   license/gitignore (this folder already has those; letting GitHub add
   its own would conflict on the first push).
2. Point this folder at it and push:

```bash
cd rxvy-hyprland-dotfiles
git remote add origin https://github.com/rxvy-dev/rxvy-hyprland-dotfiles.git
git branch -M main
git push -u origin main
```

If GitHub asks for a password, it wants a [personal access
token](https://github.com/settings/tokens) instead (GitHub dropped plain
password auth for git operations) — or push over SSH instead:

```bash
git remote set-url origin git@github.com:rxvy-dev/rxvy-hyprland-dotfiles.git
git push -u origin main
```

**On a machine that doesn't have this folder yet** (a fresh Arch install,
say), it's just the Install command above — `git clone` that URL and run
`install.sh`. That's the whole "launch" step; there's no separate build,
so cloning + `install.sh` + logging into the Hyprland session is the
entire path from a bare repo to a running desktop.

## The bar

The top bar is one continuous bordered strip rather than separate floating
pills — modules are divided by thin accent-tinted vertical rules, text is
uppercase monospace, and the active workspace is underlined instead of
filled in. The whole bar carries a soft accent-colored glow (outer shadow,
divider lines, the clock's text glow, hover states) so whichever theme
you're on is visible at a glance, not just in one corner. From left to
right: an app-menu button (`MENU`, opens rofi), workspace brackets
`[1] [2] [3]`, focused window title, then the clock centered, then a
wallpaper-cycle button (`WALL`), system stats, tray, and a power button
(`PWR`, opens wlogout) on the far right.

## Wallpapers

Nine presets ship in `hypr/wallpapers/`: `mountains`, `contours`, `grid`,
`triangles`, `blocks`, `waves`, `circuit`, `spiral`, `diagonal` — all
monochrome, all preloaded by hyprpaper at startup so switching is instant.

- **Left-click WALL** (or nothing bound to a key) cycles to the next one.
- **Right-click WALL**, or press **`SUPER + W`**, opens a visual picker —
  rofi shows an actual thumbnail grid of all nine and you click the one
  you want, instead of clicking through them one at a time.
- Either way, the choice is applied to three places at once: the live
  desktop (hyprpaper), the lock screen background (hyprlock — it no
  longer stays stuck on `mountains.png` once you've picked something
  else), and a cache file so the next login boots into your last choice
  instead of always resetting to the default.
- Drop your own images into `hypr/wallpapers/` (grayscale works best with
  this theme) — both the cycle and picker scripts pick them up
  automatically. Add them to `hypr/hyprpaper.conf`'s `preload` list too if
  you want them preloaded at startup instead of loaded on first use.

## Running a command from the bar

Click **RUN** (or `SUPER + R`) to get a rofi prompt and type any command.
Regular GUI apps launch detached, same as a normal launcher. Known
TUI/CLI programs (htop, vim, lazygit, python3, ssh, ...) instead open
inside a new kitty window so you can actually see and use them — see the
`TUI_APPS` list at the top of `scripts/run-command.sh` to add more.

## Power menu

`wlogout` (bound to **PWR** in the bar) now ships with real icons
(`wlogout/icons/`) for lock/logout/suspend/reboot/shutdown instead of
blank buttons, laid out in a single row. Edit `wlogout/style.css` for
sizing/spacing and `wlogout/layout` to change the actions or keybinds
shown in the menu itself (`l`/`e`/`s`/`r`/`p` by default).

## Quickshell — OSD + Control Center + Monitor Manager

[Quickshell](https://quickshell.org) is a Qt/QML toolkit for building small
desktop widgets. This repo uses it for three things that run **alongside**
waybar, not instead of it — so they're additive and can't be the reason
the bar itself doesn't show:

- **On-screen display** — pressing a volume or brightness key pops up a
  small pill at the bottom of the screen showing the new level, then
  auto-hides after ~1.4s. Wired through `scripts/osd-volume.sh` /
  `scripts/osd-brightness.sh`, which adjust the actual volume/brightness
  first and then notify quickshell over IPC. If quickshell isn't
  installed or isn't running, the keys still work — you just won't see
  the popup.
- **Control Center** — `SUPER + A` toggles a panel in the top-right with
  five quick actions (lock / DND toggle / mute / theme picker / monitors)
  and a live wallpaper grid: it lists whatever's actually in
  `hypr/wallpapers/` and clicking a thumbnail applies it immediately
  (same underlying logic as the WALL button and picker — lock screen and
  persistence stay in sync).
- **Monitor Manager** — `SUPER + M`, or the **MONITORS** button in the
  Control Center. Shows every connected monitor as a box on a small
  canvas, scaled proportionally — **drag them around to arrange which
  side of which they're on** (positions snap to a 10px grid). Below the
  canvas, each monitor gets its own row of **Hz** chips (only refresh
  rates its current resolution actually supports — pulled live from
  `hyprctl monitors -j`) and **rotation** chips (0°/90°/180°/270°). Hit
  **APPLY LAYOUT** and it writes `hypr/monitors.conf` (sourced from
  `hyprland.conf`, so it persists across reboots) and applies every
  monitor immediately via `hyprctl keyword monitor` — no reload or
  re-login needed. Re-opening the panel always re-fetches current state,
  so it never shows stale data from last time.

**Requires:** `quickshell` (AUR-only — `yay -S quickshell`). It's in
`install.sh`'s `AUR_PACKAGES` list already. If it's not installed, these
features just silently do nothing; nothing else in this repo depends on
it.

Colors for the QML files live in `quickshell/Theme.qml` and are kept in
sync with `hypr/colors.conf` by `reload-theme.sh`, same as every other
app here. Quickshell hot-reloads QML on save on its own, so unlike
waybar/dunst there's no restart step needed after a theme change.

## Changing the color scheme

**The easy way — a menu.** Press `SUPER + T`, or click **THEME** in the
Control Center (`SUPER + A`). Rofi shows every preset in `hypr/themes/`
with a small color swatch next to its name — pick one and it applies to
every app instantly, **including the wallpaper**: each preset names a
companion wallpaper, so picking a theme changes the colors and the
desktop/lock-screen background together. No config file editing required.

Ships with 12 presets: Classic B&W, Paper (Inverted), Red Accent, Blue
Accent, Cyan Accent, Purple Accent, Orange Accent, Pink Accent, Green
Matrix, Amber Terminal, Deep Blue (a full blue-tinted theme, not just a
blue accent dot), and Soft Gray.

To add your own, drop a new file in `hypr/themes/` with the same seven
fields as the existing ones:

```bash
NAME="My Theme"
WALLPAPER=mountains.png   # any file already in hypr/wallpapers/
BACKGROUND=0xff000000
FOREGROUND=0xffffffff
ACCENT=0xffff5555
MUTED=0xff808080
SURFACE=0xff0d0d0d
BORDER=0xff2b2b2b
```

It shows up in the picker automatically — nothing else to register. If
your theme's `NAME` contains `&`, `<`, or `>`, that's fine — the picker
escapes them for you now (an earlier version didn't, which could actually
desync the picked row from its file and silently apply the wrong theme).

**The manual way.** Everything ultimately still comes from
**`hypr/colors.conf`** (this is what the picker actually edits under the
hood):

```conf
$background = 0xff000000   # window background / base
$foreground = 0xffffffff   # text / icons
$accent     = 0xffffffff   # active border, highlights
$muted      = 0xff808080   # secondary elements
$surface    = 0xff0d0d0d   # panel background
$border_inactive = 0xff2b2b2b
```

Colors use Hyprland's `0xAARRGGBB` format. Edit the values directly if you
want something not worth saving as a preset, then run:

```bash
~/.config/hypr-scripts/reload-theme.sh
```

This regenerates the color files for Waybar, kitty, and quickshell,
patches the color block inside rofi's `config.rasi` and dunst's `dunstrc`
in place, and reloads every running app — no manual editing of each app's
config needed.

**Note:** the `accent` color now actually shows up throughout the UI —
the active-workspace underline, the window border, the bar's outer glow,
the clock, and the OSD volume bar all key off `accent` rather than
`foreground`. Earlier versions leaned on `foreground` (always white) for
most of these, which is why a colored accent could look like it "wasn't
doing anything."

## Keybinds (default: SUPER as mod key)

| Keys | Action |
|------|--------|
| `SUPER + Return` | Terminal |
| `SUPER + Q` | Close window |
| `SUPER + D` | App launcher (rofi) |
| `SUPER + R` | Run a command (opens in kitty if it's a TUI program) |
| `SUPER + W` | Visual wallpaper picker |
| `SUPER + SHIFT + D` | Run diagnostics (doctor.sh) in a kitty window |
| `SUPER + A` | Toggle Control Center (quickshell) |
| `SUPER + M` | Monitor Manager - Hz, rotation, drag to arrange |
| `SUPER + T` | Visual theme picker |
| `SUPER + E` | File manager |
| `SUPER + V` | Toggle floating |
| `SUPER + P` | Toggle pseudotile |
| `SUPER + J` | Toggle split direction |
| `SUPER + F` | Fullscreen |
| `SUPER + L` | Lock screen |
| `SUPER + 1-0` | Switch workspace |
| `SUPER + SHIFT + 1-0` | Move window to workspace |
| `SUPER + scroll` | Switch workspace (touchpad workspace-swipe was removed upstream — see note below) |
| `SUPER + SHIFT + Q` | Exit Hyprland |
| `PRINT` | Screenshot area |

Edit `hypr/hyprland.conf` to change any of these.

## Troubleshooting

**Bar (or anything else) not showing up?** Run the diagnostic script —
either `SUPER + SHIFT + D` from inside the session, or:

```bash
~/.config/hypr-scripts/doctor.sh
```

It checks, in order: whether you're actually inside a Hyprland session,
whether all the required binaries are installed, whether the Nerd Font is
installed (missing icons/boxes instead of glyphs is a font problem, not a
crash), whether `install.sh`'s symlinks are intact and pointing somewhere
real, whether `waybar/config.jsonc` is valid JSON, whether a waybar
process is actually running, and tails `~/.cache/waybar.log` (waybar is
launched through a restart-loop wrapper that logs there specifically so
crashes are diagnosable instead of silent — see the comment above the
`exec-once` line in `hyprland.conf`). One of those checks almost always
turns up the real cause — a bad module config, a missing package, or a
stale symlink from an older install.

If `doctor.sh` comes back clean but the bar is still invisible, run
`waybar` directly in an open kitty window (not through the wrapper) and
read whatever it prints — that bypasses the log entirely and shows you
the raw error live.

## Note on Hyprland version compatibility

Hyprland 0.51–0.55 removed several config options this repo used to rely
on: `dwindle:pseudotile`, the `gestures { workspace_swipe }` block,
`togglesplit` as a bare dispatcher (now needs `layoutmsg, togglesplit`),
and `windowrulev2` (replaced by `windowrule` with space-separated
matchers). This repo's `hyprland.conf` is already updated for the current
syntax. If you're on an older Hyprland and see "does not exist" errors in
the other direction, check the [Hyprland wiki changelog](https://wiki.hypr.land)
for your version.

## Uninstall

Remove the symlinks in `~/.config` and restore your backup:

```bash
rm ~/.config/hypr ~/.config/waybar ~/.config/rofi ~/.config/kitty \
   ~/.config/dunst ~/.config/wlogout ~/.config/hypr-scripts
cp -r ~/.config-backup-*/* ~/.config/
```

## License

MIT — do whatever you want with it.
