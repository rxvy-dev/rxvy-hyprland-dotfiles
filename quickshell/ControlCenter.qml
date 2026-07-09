// Toggle panel, hidden by default. Bound to SUPER+A in hyprland.conf, which
// calls: qs ipc call controlcenter toggle
// The wallpaper row is built by actually listing hypr/wallpapers/ at
// startup (via `ls`), so anything you drop in that folder shows up here
// automatically — no config file to keep in sync.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: cc

    implicitWidth: 320
    implicitHeight: 420
    color: "transparent"
    visible: false
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }
    margins.top: 50
    margins.right: 16

    Theme { id: theme }

    property string homeDir: ""
    property var wallpapers: []

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { cc.visible = !cc.visible }
        function show(): void { cc.visible = true }
        function hide(): void { cc.visible = false }
    }

    // Resolve $HOME once, then list the wallpapers directory. Both run
    // through `sh -c` rather than hardcoding a path, since QML has no
    // built-in $HOME expansion.
    Process {
        id: homeProc
        command: ["sh", "-c", "echo -n $HOME"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                cc.homeDir = this.text
                wallProc.running = true
            }
        }
    }

    Process {
        id: wallProc
        command: ["sh", "-c", "ls -1 \"" + cc.homeDir + "/.config/hypr/wallpapers\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                cc.wallpapers = this.text.trim().length > 0
                    ? this.text.trim().split("\n")
                    : []
            }
        }
    }

    Process {
        id: oneShot
        running: false
    }

    function runCmd(args) {
        oneShot.command = args
        oneShot.running = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: theme.background
        border.width: 2
        border.color: theme.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "CONTROL CENTER"
                color: theme.foreground
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
                font.pixelSize: 13
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: [
                        { label: "LOCK", cmd: ["hyprlock"] },
                        { label: "DND", cmd: ["dunstctl", "set-paused", "toggle"] },
                        { label: "MUTE", cmd: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] },
                        { label: "THEME", cmd: [cc.homeDir + "/.config/hypr-scripts/theme-picker.sh"] },
                        { label: "MONITORS", cmd: ["qs", "ipc", "call", "monitors", "toggle"] }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 6
                        color: quickArea.containsMouse ? theme.foreground : "transparent"
                        border.width: 1
                        border.color: theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: quickArea.containsMouse ? theme.background : theme.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.bold: true
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: quickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: cc.runCmd(modelData.cmd)
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            Text {
                text: "WALLPAPER"
                color: theme.muted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: cc.wallpapers
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 60
                        radius: 4
                        color: theme.surface
                        border.width: wallArea.containsMouse ? 2 : 1
                        border.color: wallArea.containsMouse ? theme.accent : theme.border
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: "file://" + cc.homeDir + "/.config/hypr/wallpapers/" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        MouseArea {
                            id: wallArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: cc.runCmd([
                                cc.homeDir + "/.config/hypr-scripts/apply-wallpaper.sh",
                                cc.homeDir + "/.config/hypr/wallpapers/" + modelData
                            ])
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 6
                color: powerArea.containsMouse ? theme.accent : theme.foreground

                Text {
                    anchors.centerIn: parent
                    text: "POWER MENU"
                    color: theme.background
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    font.pixelSize: 11
                }

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: cc.runCmd(["wlogout"])
                }
            }
        }
    }
}
