import QtQuick
import Quickshell.Services.Mpris

Panel {
    id: root

    readonly property var player: {
        const l = Mpris.players.values
        for (let i = 0; i < l.length; i++)
            if (l[i].isPlaying) return l[i]
        return l.length > 0 ? l[0] : null
    }
    readonly property bool playing: player ? player.isPlaying : false
    readonly property real len: player && player.lengthSupported ? player.length : 0
    readonly property real pos: player && player.positionSupported ? player.position : 0
    readonly property real frac: len > 0 ? Math.min(1, pos / len) : 0

    function fmt(s) {
        const t = Math.max(0, Math.floor(s))
        const m = Math.floor(t / 60)
        const r = t % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    title: "Audio // local"
    status: !player ? "idle" : playing ? "playing" : "paused"
    statusColor: playing ? Theme.accent : Theme.dim

    Timer {
        running: root.playing && root.player && root.player.positionSupported
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Item {
        id: top
        width: parent.width
        height: 72

        Rectangle {
            id: art
            width: 72
            height: 72
            color: "#55000000"
            radius: Theme.radius
            border.width: 1
            border.color: Theme.line
            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors { left: art.right; leftMargin: 16; right: btns.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 3

            Row {
                spacing: 8
                Rectangle { width: 14; height: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Mono { text: "// TRACK"; color: Theme.dim; font.pixelSize: 11; font.letterSpacing: 1.5 }
            }
            Mono {
                width: parent.width
                elide: Text.ElideRight
                text: root.player ? root.player.trackTitle.toUpperCase() : "NOTHING PLAYING"
                font.pixelSize: 22
            }
            Mono {
                width: parent.width
                elide: Text.ElideRight
                text: root.player ? root.player.trackArtist : ""
                color: Theme.dim
                font.pixelSize: 12
            }
        }

        Row {
            id: btns
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            Btn { label: "Prev"; onClicked: { if (root.player) root.player.previous() } }
            Btn { label: root.playing ? "Pause" : "Play"; accent: true; onClicked: { if (root.player) root.player.togglePlaying() } }
            Btn { label: "Next"; onClicked: { if (root.player) root.player.next() } }
        }
    }

    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 8

        Item {
            width: parent.width
            height: 14
            Mono {
                anchors.right: parent.right
                text: root.fmt(root.pos) + " / " + root.fmt(root.len)
                color: Theme.dim
                font.pixelSize: 11
            }
        }
        Item {
            width: parent.width
            height: 12

            Rectangle { id: track; width: parent.width; height: 2; color: Theme.line; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: track.width * root.frac; height: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { x: track.width * root.frac - 4; width: 8; height: 12; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    if (root.player && root.player.canSeek && root.len > 0)
                        root.player.position = mouse.x / width * root.len
                }
            }
        }
    }
}
