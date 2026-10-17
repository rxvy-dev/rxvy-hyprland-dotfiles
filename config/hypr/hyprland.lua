-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  PRISM — Hyprland rice                                           ║
-- ║                                                                  ║
-- ║  prism_generated.lua  theme + settings (written by prism, don't  ║
-- ║                       edit — use `prism-settings` / SUPER+I)     ║
-- ║  prism/core.lua       keybinds, autostart, window rules          ║
-- ║  custom.lua           YOUR tweaks — loaded last, never touched   ║
-- ╚══════════════════════════════════════════════════════════════════╝

local ok, err = pcall(require, "prism_generated")
if not ok then
    print("prism: could not load prism_generated.lua — run `prism apply`: " .. tostring(err))
    PRISM = PRISM or { terminal = "kitty", browser = "firefox", files = "thunar" }
end

require("prism.core")

-- Your own overrides (optional file)
local f = io.open(os.getenv("HOME") .. "/.config/hypr/custom.lua", "r")
if f then
    f:close()
    require("custom")
end
