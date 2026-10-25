import QtQuick
import Quickshell.Io

Panel {
    id: root

    property real cpu: 0
    property real mem: 0
    property real prevTotal: 0
    property real prevIdle: 0

    title: "Sys // monitor"
    status: "ok"

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + p[4]
            const total = p.slice(0, 8).reduce((a, b) => a + b, 0)
            const dt = total - root.prevTotal
            if (root.prevTotal > 0 && dt > 0) root.cpu = 1 - (idle - root.prevIdle) / dt
            root.prevTotal = total
            root.prevIdle = idle
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const total = Number(t.match(/MemTotal:\s+(\d+)/)[1])
            const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1])
            root.mem = 1 - avail / total
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload() }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 10

        Repeater {
            model: [ { n: "CPU", v: root.cpu }, { n: "RAM", v: root.mem } ]
            delegate: Item {
                id: row
                required property var modelData
                width: parent.width
                height: 22

                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.n
                    color: Theme.dim
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                }
                Rectangle {
                    id: track
                    x: 48
                    width: parent.width - 48 - 52
                    height: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.line

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.min(1, row.modelData.v)
                        color: row.modelData.v > 0.85 ? Theme.accent : Theme.text
                    }
                }
                Mono {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: Math.round(row.modelData.v * 100) + "%"
                    font.pixelSize: 11
                }
            }
        }
    }
}
