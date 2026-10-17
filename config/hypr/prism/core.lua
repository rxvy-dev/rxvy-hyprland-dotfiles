-- PRISM core: keybinds, autostart, window rules.
-- Safe to edit, but updates to Prism may replace it. Prefer ~/.config/hypr/custom.lua.

local P    = PRISM or {}
local term = P.terminal or "kitty"
local web  = P.browser  or "firefox"
local fm   = P.files    or "thunar"
local mod  = "SUPER"

local function b(keys, action, opts) hl.bind(keys, action, opts) end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-------------------------------------------------------------------------------
-- AUTOSTART
-------------------------------------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("prism-autostart")
end)

-------------------------------------------------------------------------------
-- APPS
-------------------------------------------------------------------------------
b(mod .. " + Return",       run(term))
b(mod .. " + SHIFT + Return", run(term .. " --class kitty-float"))
b(mod .. " + Space",        run("prism-launcher apps"))
b(mod .. " + D",            run("prism-launcher apps"))
b(mod .. " + R",            run("prism-launcher run"))
b(mod .. " + Tab",          run("prism-launcher windows"))
b(mod .. " + E",            run(fm))
b(mod .. " + B",            run(web))
b(mod .. " + I",            run("prism-settings"))
b(mod .. " + T",            run("prism-theme-menu"))
b(mod .. " + SHIFT + T",    run("prism theme next"))
b(mod .. " + W",            run("prism-theme-menu wallpaper"))
b(mod .. " + SHIFT + W",    run("prism wallpaper random"))
b(mod .. " + V",            run("prism-clipboard"))
b(mod .. " + PERIOD",       run("prism-launcher emoji"))
b(mod .. " + N",            run("prism nightlight toggle"))
b(mod .. " + F1",           run("prism-keybinds"))
b(mod .. " + SHIFT + F",    run(term .. " --hold fastfetch"))
b(mod .. " + L",            run("loginctl lock-session"))
b(mod .. " + Escape",       run("prism-power"))
b(mod .. " + SHIFT + C",    run("hyprpicker -a -n"))
b(mod .. " + SHIFT + B",    run("pkill -x waybar || waybar"))
b("CTRL + SHIFT + Escape",  run(term .. " --class kitty-float -e btop"))

-- Screenshots
b("Print",                  run("prism-screenshot region"))
b("SHIFT + Print",          run("prism-screenshot screen"))
b(mod .. " + Print",        run("prism-screenshot window"))
b(mod .. " + SHIFT + S",    run("prism-screenshot region"))

-------------------------------------------------------------------------------
-- WINDOWS
-------------------------------------------------------------------------------
b(mod .. " + Q",            hl.dsp.window.close())
b(mod .. " + F",            hl.dsp.window.fullscreen({ mode = "fullscreen" }))
b(mod .. " + M",            hl.dsp.window.fullscreen({ mode = "maximized" }))
b(mod .. " + G",            hl.dsp.window.float({ action = "toggle" }))
b(mod .. " + C",            hl.dsp.window.center())
b(mod .. " + P",            hl.dsp.window.pseudo())
b(mod .. " + O",            hl.dsp.window.pin())
b(mod .. " + J",            hl.dsp.layout("togglesplit"))
b(mod .. " + SHIFT + Q",    run("prism-power"))

for _, d in ipairs({ "left", "right", "up", "down" }) do
    b(mod .. " + " .. d,             hl.dsp.focus({ direction = d }))
    b(mod .. " + SHIFT + " .. d,     hl.dsp.window.move({ direction = d }))
end
-- vim keys too
local vim = { h = "left", l = "right", k = "up", j = "down" }
for key, d in pairs(vim) do
    b(mod .. " + ALT + " .. key, hl.dsp.focus({ direction = d }))
end

-- Resize with SUPER+CTRL+arrows (repeatable)
local rs = { left = { -40, 0 }, right = { 40, 0 }, up = { 0, -40 }, down = { 0, 40 } }
for d, v in pairs(rs) do
    b(mod .. " + CTRL + " .. d, hl.dsp.window.resize({ x = v[1], y = v[2], relative = true }), { repeating = true })
end

-- Mouse: drag to move / resize
b(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
b(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-------------------------------------------------------------------------------
-- WORKSPACES
-------------------------------------------------------------------------------
for i = 1, 10 do
    local key = i % 10
    b(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    b(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end
b(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }))
b(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }))
b(mod .. " + ALT + right",  hl.dsp.focus({ workspace = "r+1" }))
b(mod .. " + ALT + left",   hl.dsp.focus({ workspace = "r-1" }))
b(mod .. " + S",            hl.dsp.workspace.toggle_special("scratch"))
b(mod .. " + ALT + S",      hl.dsp.window.move({ workspace = "special:scratch" }))

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-------------------------------------------------------------------------------
-- MEDIA KEYS (with on-screen display)
-------------------------------------------------------------------------------
local rep = { locked = true, repeating = true }
b("XF86AudioRaiseVolume",  run("prism-osd volume up"),     rep)
b("XF86AudioLowerVolume",  run("prism-osd volume down"),   rep)
b("XF86AudioMute",         run("prism-osd volume mute"),   { locked = true })
b("XF86AudioMicMute",      run("prism-osd mic mute"),      { locked = true })
b("XF86MonBrightnessUp",   run("prism-osd brightness up"), rep)
b("XF86MonBrightnessDown", run("prism-osd brightness down"), rep)
b("XF86AudioNext",  run("playerctl next"),       { locked = true })
b("XF86AudioPrev",  run("playerctl previous"),   { locked = true })
b("XF86AudioPlay",  run("playerctl play-pause"), { locked = true })
b("XF86AudioPause", run("playerctl play-pause"), { locked = true })

-------------------------------------------------------------------------------
-- WINDOW RULES
-------------------------------------------------------------------------------
local floaters = {
    "^(pavucontrol|org.pulseaudio.pavucontrol)$", "^(nm-connection-editor)$", "^(blueman-manager)$",
    "^(dev.prism.Settings)$", "^(kitty-float)$", "^(xdg-desktop-portal-gtk)$", "^(org.gnome.Calculator)$",
    "^(swappy)$", "^(com.gabm.satty)$", "^(nwg-look)$", "^(qt6ct)$", "^(file-roller|org.gnome.FileRoller)$",
}
for i, cls in ipairs(floaters) do
    hl.window_rule({ name = "prism-float-" .. i, match = { class = cls }, float = true, center = true })
end
hl.window_rule({ name = "prism-settings-size", match = { class = "^(dev.prism.Settings)$" }, size = "980 680" })
hl.window_rule({ name = "prism-float-size",    match = { class = "^(kitty-float)$" },        size = "900 560" })
hl.window_rule({ name = "prism-dialogs", match = { title = "^(Open File|Save File|Open Folder|Save As|File Upload.*|Choose.*)$" },
                 float = true, center = true })
hl.window_rule({ name = "prism-pip", match = { title = "^(Picture-in-Picture|Picture in picture)$" },
                 float = true, pin = true, size = "480 270", move = "monitor_w-500 monitor_h-300" })
hl.window_rule({ name = "prism-idle-fullscreen", match = { fullscreen = true }, idle_inhibit = "fullscreen" })
hl.window_rule({ name = "prism-suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "prism-xwayland-drag",
                 match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
                 no_focus = true })

hl.layer_rule({ name = "prism-rofi-anim",  match = { namespace = "rofi" },          animation = "popin 90%" })
hl.layer_rule({ name = "prism-mako-anim",  match = { namespace = "notifications" }, animation = "slide" })
