import QtQuick
import Quickshell
import Quickshell.Wayland

// Idle manager (swayidle / hypridle replacement), driven by the idle-notify protocol.
// Order: dim -> lock -> screen off -> suspend. Each timer counts from your last activity.
// Every value comes from Settings (Settings -> Power & idle).
Scope {
    id: root

    readonly property bool active: Settings.idleEnabled && !Settings.idleKeepAwake
    property bool dimmed: false

    function sh(cmd) {
        if (cmd && cmd.trim() !== "") Quickshell.execDetached(["sh", "-c", cmd])
    }

    // starts the lock screen unless one is already running ("[q]s -c lock" never matches its own shell)
    function lockNow() {
        const c = Settings.lockCmd.trim()
        if (c === "") return
        sh("pgrep -f '" + c.replace(/^(.)/, "[$1]") + "' >/dev/null || " + c)
    }
    function dim() {
        if (dimmed) return
        dimmed = true
        sh("brightnessctl -s set " + Settings.idleDimLevel + "%")
    }
    function undim() {
        if (!dimmed) return
        dimmed = false
        sh("brightnessctl -r")
    }
    function dimTest() {
        dim()
        testTimer.restart()
    }
    function suspendNow() {
        if (Settings.idleLockBeforeSuspend) { lockNow(); suspendTimer.restart() }
        else sh(Settings.suspendCmd)
    }

    Timer { id: testTimer; interval: 3000; onTriggered: root.undim() }
    Timer { id: suspendTimer; interval: 1200; onTriggered: root.sh(Settings.suspendCmd) }

    // 1. dim
    IdleMonitor {
        enabled: root.active && Settings.idleDimSec > 0
        timeout: Settings.idleDimSec
        respectInhibitors: Settings.idleRespectInhibit
        onIsIdleChanged: { if (isIdle) root.dim(); else root.undim() }
    }
    // 2. lock
    IdleMonitor {
        enabled: root.active && Settings.idleLockSec > 0
        timeout: Settings.idleLockSec
        respectInhibitors: Settings.idleRespectInhibit
        onIsIdleChanged: { if (isIdle) root.lockNow() }
    }
    // 3. screen off (and back on at the first movement)
    IdleMonitor {
        enabled: root.active && Settings.idleOffSec > 0
        timeout: Settings.idleOffSec
        respectInhibitors: Settings.idleRespectInhibit
        onIsIdleChanged: { if (isIdle) root.sh(Settings.idleOffCmd); else root.sh(Settings.idleOnCmd) }
    }
    // 4. suspend
    IdleMonitor {
        enabled: root.active && Settings.idleSuspendSec > 0
        timeout: Settings.idleSuspendSec
        respectInhibitors: Settings.idleRespectInhibit
        onIsIdleChanged: { if (isIdle) root.suspendNow() }
    }

    // turning the manager off (or keep-awake on) while dimmed must bring the brightness back
    onActiveChanged: { if (!active) undim() }
}
