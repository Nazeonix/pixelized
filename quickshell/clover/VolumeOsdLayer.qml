import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    readonly property bool here: Hyprland.focusedMonitor?.name === screen?.name
    readonly property bool on: VolumeOsd.open && here

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
            label: VolumeOsd.muted ? "MUTED" : "VOLUME"
            value: VolumeOsd.value
            muted: VolumeOsd.muted
            iconRows: VolumeOsd.muted ? Icons.bm.mute : Icons.bm.vol
        }
    }
}
