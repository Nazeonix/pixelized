import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Watches the battery and raises Store.batLevel when it falls to the warning levels
// (20% / 10% / 5% by default, see Settings -> Power & idle). Shown by BatteryAlert.qml.
Scope {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev ? dev.isPresent : false
    readonly property int pct: dev ? Math.round(dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 100
    readonly property bool discharging: dev ? dev.state === UPowerDeviceState.Discharging : false

    readonly property int severity: {
        if (!Settings.batAlerts || !present || !discharging) return 0
        if (pct <= Settings.batLevel3) return 3
        if (pct <= Settings.batLevel2) return 2
        if (pct <= Settings.batLevel1) return 1
        return 0
    }
    property int shown: 0          // highest level already announced this discharge

    function announce(level) {
        shown = level
        Store.batPct = pct
        Store.batLevel = level
    }

    onSeverityChanged: {
        if (severity === 0) { shown = 0; Store.batLevel = 0; return }
        if (severity > shown) announce(severity)
    }
    // keep the number on screen current
    onPctChanged: { if (severity > 0 && Store.batLevel > 0) Store.batPct = pct }

    Component.onCompleted: { if (severity > 0) announce(severity) }

    // critical level: remind again every 2 minutes until the charger is plugged in
    Timer {
        interval: 120000
        repeat: true
        running: root.severity === 3
        onTriggered: root.announce(3)
    }
}
