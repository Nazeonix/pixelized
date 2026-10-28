import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Pixel OSD for microphone mute, keyboard backlight and airplane mode (see StatusOsd.qml).
PanelWindow {
    id: win

    readonly property bool here: Hyprland.focusedMonitor?.name === screen?.name
    readonly property bool on: StatusOsd.open && here
    readonly property string k: StatusOsd.kind

    visible: on || body.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "clover-vol"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 216

    Item {
        id: body
        anchors.fill: parent
        opacity: win.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.Linear } }

        PixelOsd {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 136

            label: win.k === "mic" ? "MICROPHONE" : (win.k === "air" ? "AIRPLANE MODE" : "KEYBOARD LIGHT")
            iconRows: win.k === "mic" ? (StatusOsd.micMuted ? Icons.bm.micoff : Icons.bm.mic)
                    : win.k === "air" ? (StatusOsd.airplane ? Icons.bm.planeoff : Icons.bm.plane)
                    : Icons.bm.kbd
            value: win.k === "mic" ? (StatusOsd.micMuted ? 0 : 1)
                 : win.k === "air" ? (StatusOsd.airplane ? 1 : 0)
                 : (StatusOsd.kbdMax > 0 ? StatusOsd.kbd / StatusOsd.kbdMax : 0)
            segs: win.k === "kbd" ? Math.max(1, Math.min(10, StatusOsd.kbdMax)) : 20
            alert: win.k === "mic" ? StatusOsd.micMuted : (win.k === "air" ? StatusOsd.airplane : false)
            valueText: win.k === "mic" ? (StatusOsd.micMuted ? "MUTED" : "LIVE")
                     : win.k === "air" ? (StatusOsd.airplane ? "ON" : "OFF")
                     : (StatusOsd.kbd === 0 ? "OFF" : StatusOsd.kbd + "/" + StatusOsd.kbdMax)
        }
    }
}
