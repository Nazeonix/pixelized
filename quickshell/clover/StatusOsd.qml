pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// OSDs for state changes that have no slider: microphone mute (Fn+F4), keyboard backlight (Fn+Space),
// airplane mode (Fn+F8). It watches the real state, so it works whether the key is handled by
// the firmware, by a Hyprland bind, or by any other tool.
Singleton {
    id: root

    property string kind: ""            // mic | kbd | air
    property bool open: false
    property bool ready: false          // ignore the values read at startup

    function flash(k) {
        if (!ready) return
        kind = k
        open = true
        hide.restart()
    }
    Timer { id: hide; interval: 1500; onTriggered: root.open = false }
    Timer { interval: 2500; running: true; onTriggered: root.ready = true }

    // ---------- microphone ----------
    readonly property var src: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.src] }
    readonly property bool micMuted: src && src.audio ? src.audio.muted : false
    onMicMutedChanged: flash("mic")

    // ---------- keyboard backlight ----------
    property string kbdPath: ""
    property int kbd: 0
    property int kbdMax: 3

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*kbd_backlight* 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: root.kbdPath = text.trim() }
    }
    FileView {
        id: kbdMaxFile
        path: root.kbdPath !== "" ? root.kbdPath + "/max_brightness" : ""
        onLoaded: { const n = parseInt(text()); if (!isNaN(n) && n > 0) root.kbdMax = n }
    }
    FileView {
        id: kbdFile
        path: root.kbdPath !== "" ? root.kbdPath + "/brightness" : ""
        onLoaded: {
            const n = parseInt(text())
            if (isNaN(n) || n === root.kbd) return
            root.kbd = n
            root.flash("kbd")
        }
    }
    // sysfs has no change events, so look at it a few times a second
    Timer {
        interval: 250
        repeat: true
        running: root.kbdPath !== ""
        onTriggered: kbdFile.reload()
    }
    onKbdPathChanged: { if (kbdPath !== "") kbdMaxFile.reload() }

    // ---------- airplane mode (rfkill) ----------
    property bool airplane: false

    Process {
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser { onRead: data => rfCheck.restart() }
    }
    Timer { id: rfCheck; interval: 250; onTriggered: rf.running = true }
    Process {
        id: rf
        command: ["sh", "-c", "rfkill -n -o TYPE,SOFT,HARD 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let any = false, all = true
                text.split("\n").forEach(l => {
                    const p = l.trim().split(/\s+/)
                    if (p.length < 3 || (p[0] !== "wlan" && p[0] !== "bluetooth")) return
                    any = true
                    if (p[1] !== "blocked" && p[2] !== "blocked") all = false
                })
                root.airplane = any && all
            }
        }
    }
    onAirplaneChanged: flash("air")
    Component.onCompleted: rf.running = true
}
