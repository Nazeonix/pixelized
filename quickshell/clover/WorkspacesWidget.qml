import QtQuick
import Quickshell
import Quickshell.Hyprland

Panel {
    id: root
    readonly property int active: Hyprland.focusedWorkspace?.id ?? 1

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: 5
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool on: wsId === root.active

                width: 28
                height: 24
                radius: Theme.radius
                color: "transparent"
                border.width: 1
                border.color: on ? Theme.accent : Theme.line

                Mono {
                    anchors.centerIn: parent
                    text: (cell.wsId < 10 ? "0" : "") + cell.wsId
                    color: cell.on ? Theme.text : Theme.dim
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + cell.wsId + " })"])
                }
            }
        }
    }
}
