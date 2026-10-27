import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    readonly property bool here: Hyprland.focusedMonitor?.name === screen?.name
    readonly property bool on: BrightnessOsd.open && here

    visible: on || body.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "clover-bri"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 140

    Item {
        id: body
        anchors.fill: parent
        opacity: win.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 110; easing.type: Easing.Linear } }

        PixelOsd {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 64
            label: "BRIGHTNESS"
            value: BrightnessOsd.value
            iconRows: Icons.bm.sun
        }
    }
}
