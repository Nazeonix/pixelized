import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Pixel alt-tab. ALT+TAB next, ALT+SHIFT+TAB prev, release ALT = switch, Esc = cancel.
// Driven by: qs -c clover ipc call alttab next|prev|commit|cancel
PanelWindow {
    id: win

    readonly property bool open: Store.altOpen && Hyprland.focusedMonitor?.name === screen?.name
    readonly property int tileW: 128
    readonly property int tileH: 108
    readonly property int n: Store.altList.length
    readonly property int perRow: Math.max(1, Math.min(n, Math.floor((width - 160) / (tileW + 4))))
    readonly property var cur: Store.altList[Store.altIndex]

    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.namespace: "clover-alttab"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) keys.forceActiveFocus()

    MouseArea { anchors.fill: parent; onClicked: Store.altCancel() }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) Store.altStep(1)
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) Store.altStep(-1)
            else if (event.key === Qt.Key_Down) Store.altStep(win.perRow)
            else if (event.key === Qt.Key_Up) Store.altStep(-win.perRow)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) Store.altCommit()
            else if (event.key === Qt.Key_Escape) Store.altCancel()
            else return
            event.accepted = true
        }
        // releasing Alt commits the highlighted window
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt && !event.isAutoRepeat) {
                Store.altCommit()
                event.accepted = true
            }
        }
    }

    Item {
        id: panel
        anchors.centerIn: parent
        width: grid.width + 20
        height: grid.height + 77

        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 80 } }

        MouseArea { anchors.fill: parent }

        // hard pixel shadow
        Rectangle { x: parent.width; y: 2; width: 2; height: parent.height; color: "#66000000" }
        Rectangle { x: 2; y: parent.height; width: parent.width; height: 2; color: "#66000000" }

        Bevel {
            anchors.fill: parent
            fill: Theme.bg
            edge: Theme.accent
        }

        // header strip
        Rectangle {
            x: 3
            y: 3
            width: parent.width - 6
            height: 24
            color: Theme.accentDim

            Item {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 11
                height: 11
                Rectangle { x: 0; y: 0; width: 5; height: 5; color: Theme.text }
                Rectangle { x: 6; y: 0; width: 5; height: 5; color: Theme.accent }
                Rectangle { x: 0; y: 6; width: 5; height: 5; color: Theme.accent }
                Rectangle { x: 6; y: 6; width: 5; height: 5; color: Theme.text }
            }
            Mono {
                x: 28
                anchors.verticalCenter: parent.verticalCenter
                text: "TASKS // SWITCH"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 2
            }
            Mono {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: (Store.altIndex + 1) + "/" + win.n
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }

        Flow {
            id: grid
            x: 10
            y: 37
            width: win.perRow * (win.tileW + 4) - 4
            spacing: 4

            Repeater {
                model: Store.altList
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === Store.altIndex

                    width: win.tileW
                    height: win.tileH

                    Bevel {
                        anchors.fill: parent
                        down: tile.sel
                        fill: tile.sel ? "#26ffffff" : "transparent"
                        edge: tile.sel ? Theme.accent : Theme.line
                    }
                    // pixel corner marks on the selected tile
                    Repeater {
                        model: tile.sel ? 4 : 0
                        Rectangle {
                            required property int index
                            width: 4
                            height: 4
                            color: Theme.accent
                            x: index % 2 === 0 ? -2 : tile.width - 2
                            y: index < 2 ? -2 : tile.height - 2
                        }
                    }

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 14
                        implicitSize: 48
                        source: Quickshell.iconPath(tile.modelData.appId, "application-x-executable")
                    }
                    Mono {
                        x: 8
                        y: 72
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: (tile.modelData.appId || "?").toUpperCase()
                        color: tile.sel ? Theme.text : Theme.dim
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: Store.altIndex = tile.index
                        onClicked: Store.altCommit()
                    }
                }
            }
        }

        // divider + title of the selected window
        Rectangle { x: 10; y: grid.y + grid.height + 8; width: parent.width - 20; height: 1; color: Theme.line }
        Item {
            x: 10
            y: grid.y + grid.height + 13
            width: parent.width - 20
            height: 22

            Mono {
                id: arrow
                anchors.verticalCenter: parent.verticalCenter
                text: ">"
                color: Theme.accent
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Mono {
                anchors { left: arrow.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                text: win.cur ? (win.cur.title !== "" ? win.cur.title : win.cur.appId).toUpperCase() : ""
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }
    }
}
