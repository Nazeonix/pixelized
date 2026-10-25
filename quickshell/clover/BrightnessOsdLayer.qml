import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: win

    readonly property bool here: Hyprland.focusedMonitor?.name === screen?.name
    readonly property bool on: BrightnessOsd.open && here
    readonly property color fill: BrightnessOsd.value > 0.85 ? Theme.accent : Theme.text

    visible: on || body.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "clover-bri"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 100

    Item {
        id: body
        anchors.fill: parent
        opacity: win.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Item {
            width: 280
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.line
            }

            Mono {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "BRI"
                color: Theme.dim
                font.pixelSize: 11
                font.letterSpacing: 1.5
            }

            Rectangle {
                x: 72
                width: parent.width - 72 - 58
                height: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.line

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.min(1, BrightnessOsd.value)
                    color: win.fill
                }
            }

            Mono {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: Math.round(BrightnessOsd.value * 100) + "%"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                color: win.fill
            }
        }
    }
}
