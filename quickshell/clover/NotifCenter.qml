import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Notification history panel (bell click). Esc / click outside closes.
PanelWindow {
    id: win

    readonly property bool open: Store.notifCenter && Hyprland.focusedMonitor?.name === screen?.name
    readonly property int barH: 48

    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    margins.bottom: barH
    WlrLayershell.namespace: "clover-notifcenter"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) keys.forceActiveFocus()

    MouseArea { anchors.fill: parent; onClicked: Store.notifCenter = false }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Store.notifCenter = false
    }

    Item {
        id: wrap
        anchors { right: parent.right; bottom: parent.bottom }
        width: 390
        height: Math.min(parent.height - 20, 560)

        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        MouseArea { anchors.fill: parent }

        Rectangle { x: parent.width; y: 2; width: 2; height: parent.height; color: "#66000000" }
        Rectangle { x: 2; y: parent.height; width: parent.width; height: 2; color: "#66000000" }

        Bevel {
            anchors.fill: parent
            fill: Theme.bg
            edge: Theme.accent
        }

        // header
        Rectangle {
            x: 3
            y: 3
            width: parent.width - 6
            height: 30
            color: Theme.accentDim

            Mono {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "NOTIFICATIONS"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 2
            }
            Mono {
                x: 150
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.count
                color: Theme.dim
                font.pixelSize: 10
            }

            Row {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 6

                // do not disturb
                Item {
                    width: 56
                    height: 22
                    Bevel {
                        anchors.fill: parent
                        down: Notifs.dnd
                        fill: Notifs.dnd ? Theme.accent : (da.containsMouse ? "#26ffffff" : "transparent")
                    }
                    Mono {
                        anchors.centerIn: parent
                        text: Notifs.dnd ? "DND ON" : "DND"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    MouseArea { id: da; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.dnd = !Notifs.dnd }
                }
                Item {
                    width: 64
                    height: 22
                    Bevel {
                        anchors.fill: parent
                        down: ca.pressed
                        fill: ca.containsMouse ? "#26ffffff" : "transparent"
                    }
                    Mono {
                        anchors.centerIn: parent
                        text: "CLEAR"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.clear() }
                }
            }
        }

        // empty state
        Mono {
            visible: Notifs.count === 0
            anchors.centerIn: parent
            text: "NO NOTIFICATIONS"
            color: Theme.dim
            font.pixelSize: 10
            font.letterSpacing: 2
        }

        ListView {
            id: list
            x: 3
            y: 36
            width: parent.width - 6
            height: parent.height - 36 - 4
            clip: true
            spacing: 4
            model: Notifs.list
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property var modelData
                readonly property bool crit: modelData.urgency === NotificationUrgency.Critical
                width: ListView.view.width
                height: Math.max(56, info.height + 20)

                Bevel {
                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                    down: ra.pressed
                    fill: ra.containsMouse ? "#14ffffff" : "transparent"
                    edge: row.crit ? Theme.accent : Theme.line
                }

                IconImage {
                    id: ic
                    x: 16
                    y: 12
                    implicitSize: 24
                    source: Notifs.iconSrc(row.modelData)
                }
                Column {
                    id: info
                    x: 52
                    y: 8
                    width: parent.width - 52 - 40
                    spacing: 3

                    Mono {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (row.modelData.appName || "").toUpperCase() + "  " + Notifs.ago(Notifs.arrived[row.modelData.id])
                        color: Theme.dim
                        font.pixelSize: 8
                        font.letterSpacing: 1.5
                    }
                    Mono {
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: row.modelData.summary
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    Mono {
                        visible: row.modelData.body !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: row.modelData.body
                        color: Theme.dim
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: ra
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Notifs.invokeDefault(row.modelData)
                }

                // dismiss
                Item {
                    anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 10 }
                    width: 20
                    height: 18
                    Bevel {
                        anchors.fill: parent
                        down: xa.pressed
                        fill: xa.containsMouse ? Theme.accent : "transparent"
                    }
                    Pix {
                        anchors.centerIn: parent
                        px: 1
                        rows: ["##...##", ".##.##.", "..###..", ".##.##.", "##...##"]
                    }
                    MouseArea {
                        id: xa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Notifs.dismiss(row.modelData)
                    }
                }
            }
        }
    }
}
