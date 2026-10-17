"""
prismlib — the theme engine behind the Prism Hyprland rice.

One theme file + one settings file go in; configs for Hyprland (Lua),
Waybar, Kitty, Rofi, Mako, Hyprlock, Hypridle, Fastfetch and GTK come out.
Both the `prism` CLI and the `prism-settings` GUI use this module.
"""

import json
import os
import shutil
import subprocess
import glob

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
DATA = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")), "prism")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "prism")

THEMES_DIR = os.path.join(DATA, "themes")
SETTINGS_FILE = os.path.join(CONFIG, "prism", "settings.json")
USER_WALL_DIRS = [os.path.join(CONFIG, "prism", "wallpapers"), os.path.join(HOME, "Pictures", "Wallpapers")]

VERSION = "1.0.0"

# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------
# A value of None means "use whatever the theme says".
DEFAULTS = {
    "theme": "tokyo-night",
    "wallpaper": None,            # None = theme wallpaper, else absolute path
    "wallpaper_mode": "fill",     # swaybg modes: fill, fit, center, tile, stretch
    "rounding": None,
    "gaps_in": None,
    "gaps_out": None,
    "border_size": None,
    "blur": None,
    "shadows": None,
    "animations": None,           # None | off | fast | smooth | bouncy
    "inactive_opacity": None,
    "terminal_opacity": None,
    "dim_inactive": False,
    "bar_position": None,         # None | top | bottom
    "bar_style": None,            # None | xp | classic | terminal | islands | flat
    "font_ui": None,
    "font_mono": None,
    "font_size": None,
    "kb_layout": "us",
    "kb_variant": "",
    "kb_options": "",
    "sensitivity": 0.0,
    "accel_flat": False,
    "natural_scroll": False,
    "touchpad_natural_scroll": True,
    "follow_mouse": 1,
    "repeat_rate": 35,
    "repeat_delay": 300,
    "monitors": [],               # [{name, mode, position, scale}]
    "night_light": False,
    "night_temp": 4500,
    "lock_timeout": 300,          # seconds, 0 = never
    "screen_off_timeout": 600,
    "suspend_timeout": 0,
    "terminal": "kitty",
    "browser": "firefox",
    "files": "thunar",
    "fastfetch_logo": "prism",    # prism | arch | arch_small | none
    "nvidia": False,
    "autostart": [],
    "show_clock_seconds": False,
    "clock_24h": True,
}


def load_settings():
    s = dict(DEFAULTS)
    try:
        with open(SETTINGS_FILE) as f:
            s.update(json.load(f))
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    return s


def save_settings(s):
    os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
    tmp = SETTINGS_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f, indent=2)
    os.replace(tmp, SETTINGS_FILE)


# --------------------------------------------------------------------------
# Themes
# --------------------------------------------------------------------------
def _parse_conf(path):
    out = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"')
    return out


def list_themes():
    themes = []
    for conf in sorted(glob.glob(os.path.join(THEMES_DIR, "*", "theme.conf"))):
        t = load_theme(os.path.basename(os.path.dirname(conf)))
        if t:
            themes.append(t)
    themes.sort(key=lambda t: (t.get("KIND") != "retro", int(t.get("ORDER", 50)), t["NAME"]))
    return themes


def load_theme(theme_id):
    d = os.path.join(THEMES_DIR, theme_id)
    path = os.path.join(d, "theme.conf")
    if not os.path.isfile(path):
        return None
    t = _parse_conf(path)
    t["ID"] = theme_id
    t["DIR"] = d
    wp = None
    for ext in ("png", "jpg", "jpeg", "webp"):
        cand = os.path.join(d, "wallpaper." + ext)
        if os.path.isfile(cand):
            wp = cand
            break
    t["WALLPAPER"] = wp
    return t


def list_wallpapers():
    walls = []
    for t in list_themes():
        if t["WALLPAPER"]:
            walls.append(t["WALLPAPER"])
    for d in USER_WALL_DIRS:
        for ext in ("png", "jpg", "jpeg", "webp"):
            walls += sorted(glob.glob(os.path.join(d, "*." + ext)))
    return walls


def resolve(theme, s):
    """Merge theme defaults with user overrides into one flat dict of look values."""
    def pick(key, tkey, cast):
        v = s.get(key)
        return cast(v if v is not None else theme[tkey])

    def truthy(x):
        return str(x).lower() in ("1", "true", "yes", "on")

    r = dict(theme)
    r["rounding"] = pick("rounding", "ROUNDING", int)
    r["gaps_in"] = pick("gaps_in", "GAPS_IN", int)
    r["gaps_out"] = pick("gaps_out", "GAPS_OUT", int)
    r["border_size"] = pick("border_size", "BORDER_SIZE", int)
    r["blur"] = pick("blur", "BLUR", truthy)
    r["shadows"] = pick("shadows", "SHADOWS", truthy)
    r["animations"] = s.get("animations") or theme["ANIMATIONS"]
    r["inactive_opacity"] = pick("inactive_opacity", "INACTIVE_OPACITY", float)
    r["terminal_opacity"] = pick("terminal_opacity", "TERM_OPACITY", float)
    r["bar_position"] = s.get("bar_position") or theme["BAR_POSITION"]
    r["bar_style"] = s.get("bar_style") or theme["BAR_STYLE"]
    r["font_ui"] = s.get("font_ui") or theme["FONT_UI"]
    r["font_mono"] = s.get("font_mono") or theme["FONT_MONO"]
    r["font_size"] = int(s.get("font_size") or theme["FONT_SIZE"])
    r["wallpaper"] = s.get("wallpaper") or theme["WALLPAPER"] or ""
    return r


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
def hx(c):
    """'#rrggbb' -> 'rrggbb'"""
    return c.lstrip("#")


def rgba(c, alpha="ff"):
    return "rgba(%s%s)" % (hx(c)[:6], alpha)


def rgb_tuple(c):
    c = hx(c)
    return int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)


def css_rgba(c, a):
    r, g, b = rgb_tuple(c)
    return "rgba(%d, %d, %d, %.2f)" % (r, g, b, a)


def lua_str(v):
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".prism-tmp"
    with open(tmp, "w") as f:
        f.write(content)
    os.replace(tmp, path)


def which(cmd):
    return shutil.which(cmd) is not None


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kw)
    except FileNotFoundError:
        return None


def spawn(cmd):
    """Start a detached background process."""
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         stdin=subprocess.DEVNULL, start_new_session=True)
    except FileNotFoundError:
        pass


def in_hyprland():
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"))


# --------------------------------------------------------------------------
# Generators
# --------------------------------------------------------------------------
ANIM_PROFILES = {
    "off": None,
    "fast": [
        ("global", 6, "bezier", "quick", None),
        ("windows", 3, "bezier", "quick", "popin 90%"),
        ("windowsOut", 2, "bezier", "quick", "popin 90%"),
        ("fade", 2, "bezier", "quick", None),
        ("layers", 2, "bezier", "quick", "fade"),
        ("workspaces", 2.5, "bezier", "quick", "slide"),
        ("border", 3, "bezier", "quick", None),
    ],
    "smooth": [
        ("global", 10, "bezier", "default", None),
        ("border", 5.39, "bezier", "easeOutQuint", None),
        ("windows", 4.79, "spring", "easy", None),
        ("windowsIn", 4.1, "spring", "easy", "popin 87%"),
        ("windowsOut", 1.49, "bezier", "linear", "popin 87%"),
        ("fadeIn", 1.73, "bezier", "almostLinear", None),
        ("fadeOut", 1.46, "bezier", "almostLinear", None),
        ("fade", 3.03, "bezier", "quick", None),
        ("layers", 3.81, "bezier", "easeOutQuint", None),
        ("layersIn", 4, "bezier", "easeOutQuint", "fade"),
        ("layersOut", 1.5, "bezier", "linear", "fade"),
        ("workspaces", 3.5, "bezier", "easeOutQuint", "slide"),
    ],
    "bouncy": [
        ("global", 10, "bezier", "default", None),
        ("border", 5, "bezier", "easeOutQuint", None),
        ("windows", 5, "spring", "bouncy", None),
        ("windowsIn", 5, "spring", "bouncy", "popin 60%"),
        ("windowsOut", 2, "bezier", "easeInOutCubic", "popin 70%"),
        ("fade", 3, "bezier", "quick", None),
        ("layers", 4, "spring", "bouncy", "slide"),
        ("workspaces", 4, "spring", "bouncy", "slidevert"),
    ],
}

CURVES = '''hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("easy",   { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333, dampening = 24.21279333 })
hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 300, damping = 14, dampening = 14 })
'''


def gen_hypr(r, s):
    L = []
    a = L.append
    a("-- ======================================================================")
    a("-- GENERATED BY PRISM — do not edit; changes are overwritten.")
    a("-- Use `prism-settings` or put your own tweaks in ~/.config/hypr/custom.lua")
    a("-- Theme: %s" % r["NAME"])
    a("-- ======================================================================")
    a("")
    a("PRISM = {")
    a("  theme    = %s," % lua_str(r["ID"]))
    a("  terminal = %s," % lua_str(s["terminal"]))
    a("  browser  = %s," % lua_str(s["browser"]))
    a("  files    = %s," % lua_str(s["files"]))
    a("}")
    a("")

    # Monitors
    if s["monitors"]:
        for m in s["monitors"]:
            if m.get("disabled"):
                a("hl.monitor({ output = %s, disabled = true })" % lua_str(m["name"]))
                continue
            a("hl.monitor({ output = %s, mode = %s, position = %s, scale = %s })" % (
                lua_str(m["name"]), lua_str(m.get("mode", "preferred")),
                lua_str(m.get("position", "auto")),
                (str(float(m["scale"])) if isinstance(m.get("scale"), (int, float)) else lua_str(m.get("scale", "auto")))))
    a('hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })')
    a("")

    # Env
    a('hl.env("XCURSOR_SIZE", "24")')
    a('hl.env("HYPRCURSOR_SIZE", "24")')
    a('hl.env("QT_QPA_PLATFORM", "wayland;xcb")')
    a('hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")')
    a('hl.env("GDK_BACKEND", "wayland,x11,*")')
    a('hl.env("SDL_VIDEODRIVER", "wayland,x11")')
    a('hl.env("MOZ_ENABLE_WAYLAND", "1")')
    a('hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")')
    a('hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. (os.getenv("PATH") or ""))')
    if s.get("nvidia"):
        a("-- NVIDIA")
        a('hl.env("LIBVA_DRIVER_NAME", "nvidia")')
        a('hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")')
        a('hl.env("NVD_BACKEND", "direct")')
    a("")

    # Look
    active = [rgba(r["BORDER_1"], "ee"), rgba(r.get("BORDER_2", r["BORDER_1"]), "ee")]
    a("hl.config({")
    a("  general = {")
    a("    gaps_in = %d, gaps_out = %d, border_size = %d," % (r["gaps_in"], r["gaps_out"], r["border_size"]))
    a("    col = {")
    a("      active_border   = { colors = { %s, %s }, angle = %s }," % (lua_str(active[0]), lua_str(active[1]), r.get("BORDER_ANGLE", "45")))
    a("      inactive_border = %s," % lua_str(rgba(r["BORDER_INACTIVE"], "cc")))
    a("    },")
    a("    resize_on_border = true,")
    a('    layout = "dwindle",')
    a("  },")
    a("  decoration = {")
    a("    rounding = %d, rounding_power = %s," % (r["rounding"], r.get("ROUNDING_POWER", "2")))
    a("    active_opacity = 1.0, inactive_opacity = %.2f," % r["inactive_opacity"])
    a("    dim_inactive = %s, dim_strength = 0.15," % ("true" if s["dim_inactive"] else "false"))
    a("    shadow = { enabled = %s, range = %s, render_power = 3, color = %s }," % (
        "true" if r["shadows"] else "false", r.get("SHADOW_RANGE", "12"), lua_str(rgba(r.get("SHADOW", "#000000"), "88"))))
    a("    blur = { enabled = %s, size = 6, passes = 3, vibrancy = 0.17, new_optimizations = true }," % (
        "true" if r["blur"] else "false"))
    a("  },")
    a("  animations = { enabled = %s }," % ("false" if r["animations"] == "off" else "true"))
    a("  input = {")
    a("    kb_layout = %s, kb_variant = %s, kb_options = %s," % (
        lua_str(s["kb_layout"]), lua_str(s["kb_variant"]), lua_str(s["kb_options"])))
    a("    follow_mouse = %d, sensitivity = %s, accel_profile = %s," % (
        int(s["follow_mouse"]), float(s["sensitivity"]), lua_str("flat" if s["accel_flat"] else "")))
    a("    natural_scroll = %s," % ("true" if s["natural_scroll"] else "false"))
    a("    repeat_rate = %d, repeat_delay = %d," % (int(s["repeat_rate"]), int(s["repeat_delay"])))
    a("    touchpad = { natural_scroll = %s, disable_while_typing = true }," % (
        "true" if s["touchpad_natural_scroll"] else "false"))
    a("  },")
    a("  misc = {")
    a("    disable_hyprland_logo = true, disable_splash_rendering = true,")
    a("    background_color = %s," % lua_str(rgba(r["BG"])))
    a("    focus_on_activate = true, mouse_move_enables_dpms = true, key_press_enables_dpms = true,")
    a("  },")
    a("  ecosystem = { no_update_news = true, no_donation_nag = true },")
    if s.get("nvidia"):
        a("  cursor = { no_hardware_cursors = true },")
    a("})")
    a("")

    prof = ANIM_PROFILES.get(r["animations"]) if r["animations"] != "off" else None
    if prof:
        a(CURVES)
        for leaf, speed, kind, curve, style in prof:
            extra = ', style = %s' % lua_str(style) if style else ""
            a('hl.animation({ leaf = %s, enabled = true, speed = %s, %s = %s%s })' % (
                lua_str(leaf), speed, kind, lua_str(curve), extra))
        a("")

    # Blur behind the bar / launcher / notifications on themes that want glass
    if r["blur"]:
        a('hl.layer_rule({ name = "prism-blur-bar",    match = { namespace = "waybar" },        blur = true, ignore_alpha = 0.3 })')
        a('hl.layer_rule({ name = "prism-blur-rofi",   match = { namespace = "rofi" },          blur = true, ignore_alpha = 0.3 })')
        a('hl.layer_rule({ name = "prism-blur-notify", match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.3 })')
        a("")
    return "\n".join(L) + "\n"


WAYBAR_LAYOUT_FOR_STYLE = {"xp": "taskbar", "classic": "taskbar", "terminal": "terminal",
                           "islands": "modern", "flat": "modern"}


def gen_waybar(r, s):
    wb = os.path.join(CONFIG, "waybar")
    layout = WAYBAR_LAYOUT_FOR_STYLE.get(r["bar_style"], "modern")
    with open(os.path.join(wb, "layouts", layout + ".jsonc")) as f:
        cfg = f.read()
    clock = ("%H:%M" if s["clock_24h"] else "%I:%M %p")
    if s["show_clock_seconds"]:
        clock = clock.replace("%M", "%M:%S")
    cfg = (cfg.replace("__POSITION__", r["bar_position"])
              .replace("__CLOCK__", clock)
              .replace("__HEIGHT__", str(int(r.get("BAR_HEIGHT", "34")) + (8 if r["bar_style"] == "islands" else 0))))
    write(os.path.join(wb, "config.jsonc"), cfg)

    c = []
    for k in ("BG", "BG_ALT", "SURFACE", "FG", "FG_DIM", "ACCENT", "ACCENT2", "URGENT", "OK", "WARN", "BAR_BG", "BAR_FG"):
        if k in r:
            c.append("@define-color %s %s;" % (k.lower(), r[k]))
    c.append("@define-color bar_bg_a %s;" % css_rgba(r.get("BAR_BG", r["BG"]), float(r.get("BAR_OPACITY", "1"))))
    c.append("@define-color surface_a %s;" % css_rgba(r["SURFACE"], 0.85))
    c.append("")
    c.append("* { font-family: \"%s\", \"Symbols Nerd Font\", \"JetBrainsMono Nerd Font\", sans-serif; font-size: %dpx; }"
             % (r["font_ui"] if r["bar_style"] not in ("terminal",) else r["font_mono"], r["font_size"] + 3))
    write(os.path.join(wb, "colors.css"), "\n".join(c) + "\n")
    write(os.path.join(wb, "style.css"),
          "/* GENERATED BY PRISM */\n@import \"colors.css\";\n@import \"styles/%s.css\";\n"
          "/* your own overrides: */\n@import \"custom.css\";\n" % r["bar_style"])
    custom = os.path.join(wb, "custom.css")
    if not os.path.exists(custom):
        write(custom, "/* Put your own Waybar CSS here. Prism never overwrites this file. */\n")


def gen_kitty(r, s):
    L = ["# GENERATED BY PRISM — theme: %s" % r["NAME"],
         "font_family      %s" % r["font_mono"],
         "font_size        %s" % (r["font_size"] + 1),
         "background_opacity %.2f" % r["terminal_opacity"],
         "foreground       %s" % r["TERM_FG"],
         "background       %s" % r["TERM_BG"],
         "cursor           %s" % r.get("TERM_CURSOR", r["ACCENT"]),
         "cursor_text_color %s" % r["TERM_BG"],
         "selection_foreground %s" % r["TERM_BG"],
         "selection_background %s" % r["ACCENT"],
         "url_color        %s" % r["ACCENT2"],
         "active_border_color   %s" % r["ACCENT"],
         "inactive_border_color %s" % r["BORDER_INACTIVE"],
         "active_tab_foreground   %s" % r["TERM_BG"],
         "active_tab_background   %s" % r["ACCENT"],
         "inactive_tab_foreground %s" % r["FG_DIM"],
         "inactive_tab_background %s" % r["SURFACE"],
         "tab_bar_background      %s" % r["TERM_BG"],
         "cursor_shape %s" % r.get("TERM_CURSOR_SHAPE", "beam"),
         ]
    for i in range(16):
        L.append("color%-2d %s" % (i, r["C%d" % i]))
    write(os.path.join(CONFIG, "kitty", "prism-theme.conf"), "\n".join(L) + "\n")


def gen_rofi(r, s):
    radius = r["rounding"]
    retro = r["bar_style"] in ("xp", "classic", "terminal")
    bw = max(1, r["border_size"])
    rasi = """/* GENERATED BY PRISM — theme: %(name)s */
* {
    bg:       %(bg)s;
    bg-alt:   %(bgalt)s;
    fg:       %(fg)s;
    fg-dim:   %(fgdim)s;
    accent:   %(accent)s;
    accent-fg:%(accentfg)s;
    urgent:   %(urgent)s;
    border-c: %(border)s;
    background-color: transparent;
    text-color: @fg;
    font: "%(font)s %(size)d";
}
window {
    width: 640px;
    background-color: @bg;
    border: %(bw)dpx;
    border-color: @border-c;
    border-radius: %(radius)dpx;
    padding: %(pad)dpx;
}
mainbox { spacing: 10px; children: [ inputbar, message, listview, mode-switcher ]; }
inputbar {
    background-color: @bg-alt;
    border-radius: %(iradius)dpx;
    padding: 10px 14px;
    spacing: 10px;
    children: [ prompt, entry ];
}
prompt { text-color: @accent; }
entry { placeholder: "%(placeholder)s"; placeholder-color: @fg-dim; cursor: text; }
message { background-color: @bg-alt; border-radius: %(iradius)dpx; padding: 8px; }
listview { lines: 9; columns: 1; spacing: 4px; scrollbar: false; fixed-height: false; }
element { padding: 8px 12px; border-radius: %(iradius)dpx; spacing: 12px; }
element normal.urgent, element alternate.urgent { text-color: @urgent; }
element selected.normal, element selected.active { background-color: @accent; text-color: @accent-fg; }
element-icon { size: 1.4em; vertical-align: 0.5; }
element-text { text-color: inherit; vertical-align: 0.5; }
mode-switcher { spacing: 6px; }
button { padding: 6px; border-radius: %(iradius)dpx; background-color: @bg-alt; text-color: @fg-dim; }
button selected { background-color: @accent; text-color: @accent-fg; }
""" % dict(name=r["NAME"], bg=css_rgba(r["BG"], 0.92 if r["blur"] else 1.0), bgalt=r["SURFACE"], fg=r["FG"],
           fgdim=r["FG_DIM"], accent=r["ACCENT"], accentfg=r.get("ACCENT_FG", r["BG"]), urgent=r["URGENT"],
           border=r["BORDER_1"], font=r["font_ui"] if r["bar_style"] != "terminal" else r["font_mono"],
           size=r["font_size"] + 1, bw=bw, radius=radius, iradius=max(0, radius - 4),
           pad=12 if not retro else 8,
           placeholder="type a command_" if r["bar_style"] == "terminal" else "Search apps…")
    write(os.path.join(CONFIG, "rofi", "prism.rasi"), rasi)


def gen_mako(r, s):
    pos = "top-right" if r["bar_position"] == "top" else "bottom-right"
    conf = """# GENERATED BY PRISM — theme: %s
font=%s %d
background-color=%sF0
text-color=%s
border-color=%s
progress-color=over %s
border-size=%d
border-radius=%d
padding=12
margin=12
width=360
height=160
icons=1
max-icon-size=48
default-timeout=6000
anchor=%s
layer=overlay

[urgency=low]
border-color=%s

[urgency=critical]
border-color=%s
default-timeout=0

[app-name=prism-osd]
anchor=bottom-center
width=300
default-timeout=1200
group-by=app-name
""" % (r["NAME"], r["font_ui"], r["font_size"] + 1, r["SURFACE"], r["FG"], r["ACCENT"], r["ACCENT"],
       max(1, r["border_size"]), r["rounding"], pos, r["BORDER_INACTIVE"], r["URGENT"])
    write(os.path.join(CONFIG, "mako", "config"), conf)


def gen_hyprlock(r, s):
    wp = r["wallpaper"] or "screenshot"
    fontc = r.get("LOCK_FG", r["FG"])
    conf = """# GENERATED BY PRISM — theme: %(name)s
$font = %(font)s

general {
    hide_cursor = true
    ignore_empty_input = true
}

animations {
    enabled = true
    bezier = linear, 1, 1, 0, 0
    animation = fadeIn, 1, 5, linear
    animation = fadeOut, 1, 5, linear
    animation = inputFieldDots, 1, 2, linear
}

background {
    monitor =
    path = %(wp)s
    blur_passes = %(blur)d
    brightness = 0.7
}

label {
    monitor =
    text = cmd[update:1000] date +"%(clock)s"
    color = %(fg)s
    font_size = 96
    font_family = $font
    position = 0, 160
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] date +"%%A, %%d %%B"
    color = %(fgdim)s
    font_size = 22
    font_family = $font
    position = 0, 70
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 320, 56
    outline_thickness = %(bw)d
    outer_color = %(accent)s
    inner_color = %(surface)s
    font_color = %(fg)s
    check_color = %(accent2)s
    fail_color = %(urgent)s
    fade_on_empty = false
    rounding = %(radius)d
    font_family = $font
    placeholder_text = <i>%(placeholder)s</i>
    fail_text = $PAMFAIL
    dots_spacing = 0.3
    position = 0, -40
    halign = center
    valign = center
}

label {
    monitor =
    text = Hi, $USER
    color = %(fgdim)s
    font_size = 14
    font_family = $font
    position = 0, -110
    halign = center
    valign = center
}
""" % dict(name=r["NAME"], font=r["font_ui"], wp=wp, blur=3 if r["blur"] else 0,
           clock="%H:%M" if s["clock_24h"] else "%I:%M", fg=rgba(fontc), fgdim=rgba(r.get("LOCK_FG_DIM", r["FG_DIM"])),
           bw=max(2, r["border_size"]), accent=rgba(r["ACCENT"]), surface=rgba(r["SURFACE"], "dd"),
           accent2=rgba(r["ACCENT2"]), urgent=rgba(r["URGENT"]), radius=r["rounding"] if r["rounding"] else 0,
           placeholder="password_" if r["bar_style"] == "terminal" else "Password…")
    write(os.path.join(CONFIG, "hypr", "hyprlock.conf"), conf)


def gen_hypridle(r, s):
    L = ["# GENERATED BY PRISM",
         "general {",
         "    lock_cmd = pidof hyprlock || hyprlock",
         "    before_sleep_cmd = loginctl lock-session",
         "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({action = \"on\"})'",
         "}", ""]
    if int(s["lock_timeout"]) > 0:
        L += ["listener {", "    timeout = %d" % int(s["lock_timeout"]),
              "    on-timeout = loginctl lock-session", "}", ""]
    if int(s["screen_off_timeout"]) > 0:
        L += ["listener {", "    timeout = %d" % int(s["screen_off_timeout"]),
              "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({action = \"off\"})'",
              "    on-resume = hyprctl dispatch 'hl.dsp.dpms({action = \"on\"})'", "}", ""]
    if int(s["suspend_timeout"]) > 0:
        L += ["listener {", "    timeout = %d" % int(s["suspend_timeout"]),
              "    on-timeout = systemctl suspend", "}", ""]
    write(os.path.join(CONFIG, "hypr", "hypridle.conf"), "\n".join(L))


def gen_fastfetch(r, s):
    logo = s.get("fastfetch_logo", "prism")
    if logo == "prism":
        logo_obj = {"type": "file", "source": os.path.join(CONFIG, "fastfetch", "logo-prism.txt"),
                    "color": {"1": "blue", "2": "magenta"}, "padding": {"top": 1, "right": 3}}
    elif logo == "none":
        logo_obj = {"type": "none"}
    else:
        logo_obj = {"source": logo, "color": {"1": "blue", "2": "magenta"}, "padding": {"right": 3}}
    sep = " > " if r["bar_style"] == "terminal" else "  "
    mods = [
        {"type": "title", "color": {"user": "blue", "at": "white", "host": "magenta"}},
        {"type": "separator", "string": "─"},
        {"type": "os", "key": " os"},
        {"type": "kernel", "key": " kernel"},
        {"type": "wm", "key": " wm"},
        {"type": "custom", "key": " theme", "format": "Prism · %s" % r["NAME"]},
        {"type": "terminal", "key": " term"},
        {"type": "shell", "key": " shell"},
        {"type": "packages", "key": " pkgs"},
        {"type": "cpu", "key": " cpu"},
        {"type": "gpu", "key": " gpu"},
        {"type": "memory", "key": " ram"},
        {"type": "disk", "key": " disk", "folders": "/"},
        {"type": "uptime", "key": " up"},
        "break",
        {"type": "colors", "symbol": "circle"},
    ]
    cfg = {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "logo": logo_obj,
        "display": {"separator": sep, "color": {"keys": "blue", "title": "magenta"}, "key": {"width": 10}},
        "modules": mods,
    }
    write(os.path.join(CONFIG, "fastfetch", "config.jsonc"),
          "// GENERATED BY PRISM\n" + json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")


def apply_gtk(r, s):
    if not which("gsettings"):
        return
    dark = r.get("MODE", "dark") == "dark"
    iface = "org.gnome.desktop.interface"
    gtk_theme = "adw-gtk3-dark" if dark else "adw-gtk3"
    calls = [
        ("color-scheme", "prefer-dark" if dark else "prefer-light"),
        ("gtk-theme", gtk_theme),
        ("icon-theme", r.get("ICONS", "Papirus-Dark" if dark else "Papirus")),
        ("font-name", "%s %d" % (r["font_ui"], r["font_size"])),
        ("monospace-font-name", "%s %d" % (r["font_mono"], r["font_size"])),
        ("cursor-theme", r.get("CURSOR", "Adwaita")),
    ]
    if r.get("GTK_ACCENT"):
        calls.append(("accent-color", r["GTK_ACCENT"]))
    for k, v in calls:
        run(["gsettings", "set", iface, k, v])
    # gtk-3 settings.ini for apps that do not read gsettings
    ini = "[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\ngtk-font-name=%s %d\n" \
          "gtk-application-prefer-dark-theme=%d\ngtk-cursor-theme-name=%s\n" % (
              gtk_theme, r.get("ICONS", "Papirus-Dark" if dark else "Papirus"), r["font_ui"], r["font_size"],
              1 if dark else 0, r.get("CURSOR", "Adwaita"))
    write(os.path.join(CONFIG, "gtk-3.0", "settings.ini"), ini)


# --------------------------------------------------------------------------
# Runtime (reloading things)
# --------------------------------------------------------------------------
def set_wallpaper_runtime(r, s):
    wp = r["wallpaper"]
    run(["pkill", "-x", "swaybg"])
    if wp and os.path.isfile(wp):
        spawn(["swaybg", "-i", wp, "-m", s.get("wallpaper_mode", "fill")])
    else:
        spawn(["swaybg", "-c", r["BG"]])


def nightlight_runtime(s):
    run(["pkill", "-x", "hyprsunset"])
    if s.get("night_light") and which("hyprsunset"):
        spawn(["hyprsunset", "-t", str(int(s.get("night_temp", 4500)))])
    run(["pkill", "-RTMIN+8", "waybar"])


def reload_runtime(r, s, wallpaper=True):
    if not in_hyprland():
        return
    run(["hyprctl", "reload"])
    if run(["pgrep", "-x", "waybar"]) and run(["pgrep", "-x", "waybar"]).returncode == 0:
        run(["pkill", "-SIGUSR2", "-x", "waybar"])
    else:
        spawn(["waybar"])
    run(["pkill", "-SIGUSR1", "-x", "kitty"])
    if which("makoctl"):
        if run(["makoctl", "reload"]).returncode != 0:
            spawn(["mako"])
    run(["pkill", "-x", "hypridle"])
    spawn(["hypridle"])
    if wallpaper:
        set_wallpaper_runtime(r, s)
    apply_gtk(r, s)


def generate(s=None):
    s = s or load_settings()
    theme = load_theme(s["theme"]) or load_theme(DEFAULTS["theme"]) or list_themes()[0]
    r = resolve(theme, s)
    write(os.path.join(CONFIG, "hypr", "prism_generated.lua"), gen_hypr(r, s))
    gen_waybar(r, s)
    gen_kitty(r, s)
    gen_rofi(r, s)
    gen_mako(r, s)
    gen_hyprlock(r, s)
    gen_hypridle(r, s)
    gen_fastfetch(r, s)
    os.makedirs(CACHE, exist_ok=True)
    write(os.path.join(CACHE, "current.json"), json.dumps({"theme": r["ID"], "name": r["NAME"],
                                                           "wallpaper": r["wallpaper"]}))
    return r


def apply(s=None, reload=True, wallpaper=True):
    s = s or load_settings()
    r = generate(s)
    if reload:
        reload_runtime(r, s, wallpaper=wallpaper)
    else:
        apply_gtk(r, s)
    return r


def set_theme(theme_id, keep_wallpaper=False):
    if not load_theme(theme_id):
        raise ValueError("unknown theme: %s" % theme_id)
    s = load_settings()
    s["theme"] = theme_id
    if not keep_wallpaper:
        s["wallpaper"] = None
    # theme-specific look should win when switching themes
    for k in ("rounding", "gaps_in", "gaps_out", "border_size", "blur", "shadows", "animations",
              "inactive_opacity", "terminal_opacity", "bar_style", "bar_position", "font_ui", "font_mono", "font_size"):
        s[k] = None
    save_settings(s)
    r = apply(s)
    notify("Theme: %s" % r["NAME"], r.get("DESC", ""))
    return r


def notify(title, body="", app="Prism"):
    if which("notify-send") and in_hyprland():
        run(["notify-send", "-a", app, title, body])


def monitors():
    p = run(["hyprctl", "-j", "monitors", "all"])
    if not p or p.returncode != 0:
        return []
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return []
