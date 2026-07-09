// Entry point. Quickshell auto-loads this from ~/.config/quickshell/shell.qml
//
// This ships three small pieces that run alongside waybar rather than
// replacing it:
//   - Osd.qml             volume/brightness popup (see hyprland.conf's
//                          XF86Audio*/XF86MonBrightness* binds)
//   - ControlCenter.qml    quick-toggle panel + live wallpaper picker
//                          (SUPER+A to toggle)
//   - MonitorManager.qml   drag-to-arrange monitor layout, Hz + rotation
//                          per monitor (SUPER+M to toggle)
//
// All three stay invisible and idle until triggered over IPC, so this
// adds nothing to the screen on its own.
import Quickshell
import QtQuick

ShellRoot {
    Osd {}
    ControlCenter {}
    MonitorManager {}
}
