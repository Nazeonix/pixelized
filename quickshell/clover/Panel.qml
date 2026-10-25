import QtQuick

// Terminal-style panel: near-black fill, 1px line, mono header strip.
Item {
    id: root

    property string title: ""
    property string status: ""
    property color statusColor: Theme.dim
    property bool accentBorder: false
    default property alias content: slot.data
    readonly property int headerH: (title !== "" || status !== "") ? 30 : 0

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: root.accentBorder ? Theme.accentDim : Theme.line
    }

    Item {
        visible: root.headerH > 0
        x: 1
        y: 1
        width: parent.width - 2
        height: root.headerH

        Mono {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.title.toUpperCase()
            color: Theme.dim
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Mono {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: root.status.toUpperCase()
            color: root.statusColor
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.line
        }
    }

    Item {
        id: slot
        anchors {
            fill: parent
            margins: 14
            topMargin: root.headerH > 0 ? root.headerH + 12 : 14
        }
    }
}
