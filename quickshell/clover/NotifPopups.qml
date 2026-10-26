import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// Notification toasts, top-right of the focused screen.
PanelWindow {
    id: win

    readonly property bool here: Hyprland.focusedMonitor?.name === screen?.name
    visible: here && Notifs.popups.length > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 40; right: 10 }
    implicitWidth: 360
    implicitHeight: Math.max(1, stack.height)
    WlrLayershell.namespace: "clover-notify"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
        id: stack
        width: parent.width
        spacing: 8

        add: Transition { NumberAnimation { property: "x"; from: 380; to: 0; duration: 160; easing.type: Easing.OutCubic } }
        move: Transition { NumberAnimation { property: "y"; duration: 120; easing.type: Easing.OutCubic } }

        Repeater {
            model: Notifs.popups

            delegate: Item {
                id: card
                required property var modelData        // Notification
                readonly property bool crit: modelData.urgency === NotificationUrgency.Critical
                readonly property int total: modelData.expireTimeout > 0 ? modelData.expireTimeout * 1000 : (crit ? 0 : Settings.popupSec * 1000)
                property int remaining: total
                readonly property var acts: Array.from(modelData.actions).filter(a => a.identifier !== "default")

                width: stack.width
                height: body.height + 12

                Connections {
                    target: card.modelData
                    function onClosed() { Notifs.hidePopup(card.modelData) }
                }
                Timer {
                    interval: 50
                    repeat: true
                    running: card.total > 0 && !hover.containsMouse
                    onTriggered: {
                        card.remaining -= 50
                        if (card.remaining <= 0) Notifs.hidePopup(card.modelData)
                    }
                }

                // hard pixel shadow
                Rectangle { x: parent.width; y: 2; width: 2; height: parent.height; color: "#66000000" }
                Rectangle { x: 2; y: parent.height; width: parent.width; height: 2; color: "#66000000" }

                Bevel {
                    anchors.fill: parent
                    fill: Theme.bg
                    edge: card.crit ? Theme.accent : Theme.line
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) Notifs.dismiss(card.modelData)
                        else Notifs.invokeDefault(card.modelData)
                    }
                }

                Item {
                    id: body
                    x: 10
                    y: 6
                    width: parent.width - 20
                    height: head.height + 6 + txt.height + (card.acts.length > 0 ? actRow.height + 8 : 0)

                    // header: app icon + app name + close
                    Item {
                        id: head
                        width: parent.width
                        height: 18

                        IconImage {
                            id: ic
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 16
                            source: Notifs.iconSrc(card.modelData)
                        }
                        Mono {
                            anchors { left: ic.right; leftMargin: 8; right: xb.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: (card.modelData.appName || "NOTIFICATION").toUpperCase()
                            color: card.crit ? Theme.accent : Theme.dim
                            font.pixelSize: 9
                            font.letterSpacing: 1.5
                        }
                        Item {
                            id: xb
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 18
                            height: 16
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
                                onClicked: Notifs.dismiss(card.modelData)
                            }
                        }
                    }

                    Column {
                        id: txt
                        y: head.height + 6
                        width: parent.width
                        spacing: 3

                        Mono {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: card.modelData.summary
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                        }
                        Mono {
                            visible: card.modelData.body !== ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            text: card.modelData.body
                            color: Theme.dim
                            font.pixelSize: 10
                        }
                    }

                    Row {
                        id: actRow
                        visible: card.acts.length > 0
                        y: txt.y + txt.height + 8
                        spacing: 6

                        Repeater {
                            model: card.acts
                            delegate: Item {
                                id: ab
                                required property var modelData
                                width: at.implicitWidth + 16
                                height: 20

                                Bevel {
                                    anchors.fill: parent
                                    down: aa.pressed
                                    fill: aa.containsMouse ? "#26ffffff" : "transparent"
                                }
                                Mono {
                                    id: at
                                    anchors.centerIn: parent
                                    text: ab.modelData.text.toUpperCase()
                                    font.pixelSize: 9
                                    font.letterSpacing: 1
                                }
                                MouseArea {
                                    id: aa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { ab.modelData.invoke(); Notifs.dismiss(card.modelData) }
                                }
                            }
                        }
                    }
                }

                // time left (pixel bar)
                Rectangle {
                    visible: card.total > 0
                    x: 3
                    y: parent.height - 4
                    width: Math.max(0, (parent.width - 6) * card.remaining / card.total)
                    height: 2
                    color: Theme.accent
                }
            }
        }
    }
}
