pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real value: 0
    property bool open: false
    property string pending: ""

    function flash(v) {
        value = Math.max(0, Math.min(1, v))
        open = true
        hide.restart()
    }

    // arg: "" = just read, "5%+" / "5%-" = change, then read
    function run(arg) {
        if (bri.running) { pending = arg; return }
        bri.command = arg === "" ? ["brightnessctl", "-m"] : ["brightnessctl", "-m", "set", arg]
        bri.running = true
    }
    function read() { run("") }
    function step(arg) { run(arg) }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.open = false
    }

    // brightnessctl -m → device,class,current,percent%,max
    Process {
        id: bri
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                const n = Number((p.length >= 4 ? p[3] : "").replace("%", ""))
                if (!isNaN(n) && p.length >= 4) root.flash(n / 100)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.log("brightnessctl:", text.trim())
        }
        onExited: {
            if (root.pending !== "") {
                const a = root.pending
                root.pending = ""
                root.run(a)
            }
        }
    }
}
