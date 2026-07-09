// Monitor arrangement panel. Toggle with SUPER+M, or the MONITORS button
// in the Control Center. Drag monitors on the canvas to reposition them
// relative to each other ("place beside"), pick a refresh rate and
// rotation per monitor from the chip rows below, then hit APPLY - that
// writes hypr/monitors.conf (sourced from hyprland.conf, so it persists)
// and applies every monitor live via `hyprctl keyword monitor`, no
// reload/re-login needed.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: mm

    implicitWidth: 640
    implicitHeight: 560
    color: "transparent"
    visible: false
    exclusiveZone: 0

    anchors {
        top: true
        left: true
    }
    margins.top: 50
    margins.left: 16

    Theme { id: theme }

    property string homeDir: ""
    property var monitors: []
    readonly property real canvasScale: 0.07
    readonly property int canvasPad: 20

    IpcHandler {
        target: "monitors"
        function toggle(): void { mm.visible = !mm.visible }
        function show(): void { mm.visible = true }
        function hide(): void { mm.visible = false }
    }

    onVisibleChanged: {
        if (visible) {
            homeProc.running = true
            monitorProc.running = true
        }
    }

    Process {
        id: homeProc
        command: ["sh", "-c", "echo -n $HOME"]
        stdout: StdioCollector {
            onStreamFinished: { mm.homeDir = this.text }
        }
    }

    // Re-fetches current monitor state (position, resolution, refresh
    // rate, rotation, available modes) each time the panel opens, so it
    // always reflects reality rather than stale data from last time.
    Process {
        id: monitorProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text)
                    var list = []
                    for (var i = 0; i < data.length; i++) {
                        var m = data[i]
                        var hzSet = {}
                        var hzList = []
                        var modes = m.availableModes || []
                        for (var j = 0; j < modes.length; j++) {
                            var match = modes[j].match(/^(\d+)x(\d+)@([\d.]+)Hz$/)
                            if (match && parseInt(match[1]) === m.width && parseInt(match[2]) === m.height) {
                                var hz = Math.round(parseFloat(match[3]))
                                if (!hzSet[hz]) { hzSet[hz] = true; hzList.push(hz) }
                            }
                        }
                        hzList.sort(function(a, b) { return b - a })
                        if (hzList.length === 0) { hzList.push(Math.round(m.refreshRate)) }

                        list.push({
                            name: m.name,
                            width: m.width,
                            height: m.height,
                            x: m.x,
                            y: m.y,
                            refreshRate: Math.round(m.refreshRate),
                            transform: m.transform || 0,
                            scale: m.scale || 1,
                            hzOptions: hzList
                        })
                    }
                    mm.monitors = list
                } catch (e) {
                    console.log("MonitorManager: failed to parse hyprctl monitors -j:", e)
                }
            }
        }
    }

    Process {
        id: applyProc
        running: false
    }

    function updateMonitor(idx, fields) {
        var arr = mm.monitors.slice()
        arr[idx] = Object.assign({}, arr[idx], fields)
        mm.monitors = arr
    }

    function applyLayout() {
        var lines = []
        for (var i = 0; i < mm.monitors.length; i++) {
            var m = mm.monitors[i]
            lines.push(
                "monitor=" + m.name + "," + m.width + "x" + m.height + "@" + m.refreshRate +
                "," + Math.round(m.x) + "x" + Math.round(m.y) + "," + m.scale +
                ",transform," + m.transform
            )
        }
        applyProc.command = [mm.homeDir + "/.config/hypr-scripts/apply-monitor-layout.sh", lines.join("\n")]
        applyProc.running = true
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
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "MONITORS"
                    color: theme.foreground
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "drag to arrange"
                    color: theme.muted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            // Draggable arrangement canvas
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                color: theme.surface
                border.width: 1
                border.color: theme.border
                clip: true

                Repeater {
                    model: mm.monitors
                    delegate: Rectangle {
                        id: monRect
                        property int monIndex: index
                        property bool rotated: (modelData.transform % 2) === 1
                        width: Math.max(40, (rotated ? modelData.height : modelData.width) * mm.canvasScale)
                        height: Math.max(30, (rotated ? modelData.width : modelData.height) * mm.canvasScale)
                        x: mm.canvasPad + modelData.x * mm.canvasScale
                        y: mm.canvasPad + modelData.y * mm.canvasScale
                        color: theme.background
                        radius: 3
                        border.width: dragArea.drag.active ? 2 : 1
                        border.color: dragArea.drag.active ? theme.accent : theme.foreground
                        z: dragArea.drag.active ? 10 : 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: theme.foreground
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: parent
                            drag.axis: Drag.XAndYAxis
                            onReleased: {
                                var snappedX = Math.round((monRect.x - mm.canvasPad) / mm.canvasScale / 10) * 10
                                var snappedY = Math.round((monRect.y - mm.canvasPad) / mm.canvasScale / 10) * 10
                                mm.updateMonitor(monRect.monIndex, { x: snappedX, y: snappedY })
                            }
                        }
                    }
                }
            }

            // Per-monitor Hz + rotation controls, scrollable if there are
            // enough monitors to need it
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: monitorControls.height
                clip: true

                ColumnLayout {
                    id: monitorControls
                    width: parent.width
                    spacing: 14

                    Repeater {
                        model: mm.monitors
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            property int monIndex: index

                            Text {
                                text: modelData.name + "   " + modelData.width + "x" + modelData.height
                                color: theme.foreground
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                                font.pixelSize: 11
                            }

                            Text {
                                text: "HZ"
                                color: theme.muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                            }

                            RowLayout {
                                spacing: 6
                                Repeater {
                                    model: modelData.hzOptions
                                    delegate: Rectangle {
                                        property int hzVal: modelData
                                        property bool active: mm.monitors[monIndex] && mm.monitors[monIndex].refreshRate === hzVal
                                        width: 44; height: 26; radius: 4
                                        color: active ? theme.foreground : "transparent"
                                        border.width: 1
                                        border.color: active ? theme.foreground : theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: hzVal
                                            color: active ? theme.background : theme.foreground
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: mm.updateMonitor(monIndex, { refreshRate: hzVal })
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "ROTATION"
                                color: theme.muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                            }

                            RowLayout {
                                spacing: 6
                                Repeater {
                                    model: [
                                        { label: "0°", val: 0 },
                                        { label: "90°", val: 1 },
                                        { label: "180°", val: 2 },
                                        { label: "270°", val: 3 }
                                    ]
                                    delegate: Rectangle {
                                        property bool active: mm.monitors[monIndex] && mm.monitors[monIndex].transform === modelData.val
                                        width: 44; height: 26; radius: 4
                                        color: active ? theme.foreground : "transparent"
                                        border.width: 1
                                        border.color: active ? theme.foreground : theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: active ? theme.background : theme.foreground
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: mm.updateMonitor(monIndex, { transform: modelData.val })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 6
                color: applyArea.containsMouse ? theme.accent : theme.foreground

                Text {
                    anchors.centerIn: parent
                    text: "APPLY LAYOUT"
                    color: theme.background
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    font.pixelSize: 11
                }

                MouseArea {
                    id: applyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: mm.applyLayout()
                }
            }
        }
    }
}
