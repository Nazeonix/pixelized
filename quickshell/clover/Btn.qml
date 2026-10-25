import QtQuick

Item {
    id: root

    property string label: ""
    property bool accent: false
    property bool solid: false
    signal clicked()

    implicitWidth: t.implicitWidth + 28
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: ma.pressed ? "#26ffffff" : ma.containsMouse ? "#14ffffff" : (root.solid ? Theme.bg : "transparent")
        border.width: 1
        border.color: root.accent ? Theme.accent : Theme.line
    }
    Mono {
        id: t
        anchors.centerIn: parent
        text: root.label.toUpperCase()
        font.pixelSize: 11
        font.letterSpacing: 1.5
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
