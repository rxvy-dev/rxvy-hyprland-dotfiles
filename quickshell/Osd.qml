// On-screen display for volume/brightness. Stays invisible and idle until
// something calls it over IPC:
//   qs ipc call osd show volume 0.75
//   qs ipc call osd show brightness 0.40
// scripts/osd-volume.sh and scripts/osd-brightness.sh do exactly that after
// adjusting the actual level, and are what the volume/brightness keys in
// hyprland.conf are bound to.
import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
    id: osd

    implicitWidth: 260
    implicitHeight: 60
    color: "transparent"
    visible: false
    exclusiveZone: 0

    anchors {
        bottom: true
    }
    margins.bottom: 70

    property real level: 0.0        // 0..1
    property string kind: "volume"  // "volume" | "brightness"

    Theme { id: theme }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: osd.visible = false
    }

    IpcHandler {
        target: "osd"
        function show(kindArg: string, levelArg: real): void {
            osd.kind = kindArg
            osd.level = levelArg
            osd.visible = true
            hideTimer.restart()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: theme.background
        border.width: 1
        border.color: theme.accent

        Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: osd.kind === "brightness" ? "BRT" : (osd.level <= 0.001 ? "MUTE" : "VOL")
                color: theme.foreground
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
                font.pixelSize: 12
            }

            Rectangle {
                width: 140
                height: 8
                radius: 4
                color: theme.border
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, osd.level))
                    height: parent.height
                    radius: 4
                    color: theme.accent

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(osd.level * 100) + "%"
                color: theme.muted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }
        }
    }
}
