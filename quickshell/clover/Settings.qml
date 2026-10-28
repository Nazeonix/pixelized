pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent user settings (settings.json next to the other Clover files).
// Edited from SettingsApp.qml; other components just read these properties.
// The "wallpaper" preset takes its colors from the current wallpaper via matugen (Material You).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/quickshell/clover"
    readonly property string path: dir + "/settings.json"

    property string preset: "orange"
    property bool clock24: true
    property bool cpuGauge: true
    property bool reduceMotion: false
    property bool highContrast: false
    property bool pixelAvatar: true
    property string userName: ""
    property string termCmd: "kitty"
    property string filesCmd: "nautilus"
    property int popupSec: 6
    property string wpScheme: "scheme-tonal-spot"

    // ---- low battery alerts (BatteryWatch.qml) ----
    property bool batAlerts: true
    property int batLevel1: 20
    property int batLevel2: 10
    property int batLevel3: 5

    // ---- idle manager (Idle.qml) ----
    property bool idleEnabled: true
    property bool idleKeepAwake: false          // session only, not saved
    property int idleDimSec: 120                // 0 = off
    property int idleDimLevel: 15               // percent brightness while dimmed
    property int idleLockSec: 300
    property int idleOffSec: 360
    property int idleSuspendSec: 0
    property bool idleRespectInhibit: true
    property bool idleLockBeforeSuspend: true
    property string lockCmd: "qs -c lock"
    property string idleOffCmd: "hyprctl dispatch dpms off"
    property string idleOnCmd: "hyprctl dispatch dpms on"
    property string suspendCmd: "systemctl suspend"

    // ---- colors taken from the wallpaper (cached in wallpaper-colors.json) ----
    property var wp: ({})
    property string wpStatus: ""
    readonly property var wpSchemes: ["scheme-tonal-spot", "scheme-vibrant", "scheme-expressive", "scheme-neutral", "scheme-fidelity", "scheme-content", "scheme-monochrome"]
    readonly property var wpSchemeNames: ["Tonal", "Vibrant", "Expressive", "Neutral", "Fidelity", "Content", "Mono"]

    readonly property var presets: ({
        orange:    { name: "Orange",    accent: "#ff7a18", dim: "#8a3d0a" },
        amber:     { name: "Amber",     accent: "#ffb000", dim: "#6e4c00" },
        ember:     { name: "Ember",     accent: "#ff4d00", dim: "#7a2500" },
        white:     { name: "White",     accent: "#f5f5f5", dim: "#55555a" },
        wallpaper: { name: "Wallpaper", accent: "#ff7a18", dim: "#8a3d0a" }     // fallback until colors are extracted
    })
    readonly property var presetIds: ["orange", "amber", "ember", "white", "wallpaper"]

    readonly property bool useWp: preset === "wallpaper" && wp.accent !== undefined
    readonly property color accent: useWp ? wp.accent : (presets[preset] ? presets[preset].accent : "#ff7a18")
    readonly property color accentDim: useWp ? wp.accentDim : (presets[preset] ? presets[preset].dim : "#8a3d0a")
    readonly property string displayName: userName !== "" ? userName : (Quickshell.env("USER") || "user")

    // keys that are stored in the file
    readonly property var keys: ["preset", "clock24", "cpuGauge", "reduceMotion", "highContrast", "pixelAvatar", "userName", "termCmd", "filesCmd", "popupSec", "wpScheme", "batAlerts", "batLevel1", "batLevel2", "batLevel3", "idleEnabled", "idleDimSec", "idleDimLevel", "idleLockSec", "idleOffSec", "idleSuspendSec", "idleRespectInhibit", "idleLockBeforeSuspend", "lockCmd", "idleOffCmd", "idleOnCmd", "suspendCmd"]

    function swatch(id) {
        if (id === "wallpaper" && wp.accent !== undefined) return wp.accent
        return presets[id] ? presets[id].accent : "#ff7a18"
    }

    function set(key, value) {
        root[key] = value
        save()
        if (key === "wpScheme" && preset === "wallpaper") refreshColors()
        if (key === "preset" && value === "wallpaper") refreshColors()
    }
    function save() { saveTimer.restart() }
    function reload() { file.reload() }

    // bundles used by the Presets page
    function applyBundle(id) {
        if (presets[id]) { preset = id; if (id === "wallpaper") refreshColors() }
        else if (id === "minimal") { cpuGauge = false; reduceMotion = true; Store.titlebars = false }
        else if (id === "full") { cpuGauge = true; reduceMotion = false; Store.titlebars = true }
        save()
    }

    function resetAll() {
        preset = "orange"; clock24 = true; cpuGauge = true; reduceMotion = false; highContrast = false
        pixelAvatar = true; userName = ""; termCmd = "kitty"; filesCmd = "nautilus"; popupSec = 6
        wpScheme = "scheme-tonal-spot"
        batAlerts = true; batLevel1 = 20; batLevel2 = 10; batLevel3 = 5
        idleEnabled = true; idleDimSec = 120; idleDimLevel = 15; idleLockSec = 300; idleOffSec = 360; idleSuspendSec = 0
        idleRespectInhibit = true; idleLockBeforeSuspend = true
        lockCmd = "qs -c lock"; idleOffCmd = "hyprctl dispatch dpms off"; idleOnCmd = "hyprctl dispatch dpms on"; suspendCmd = "systemctl suspend"
        Store.titlebars = true
        Notifs.dnd = false
        save()
    }

    // ---- matugen ----
    property bool wpGot: false
    property int wpTry: 0
    property string wpErr: ""
    property string wpParseFail: ""

    function refreshColors() {
        const img = (typeof Wallpaper !== "undefined") ? Wallpaper.current : ""
        if (!img) { wpStatus = "No wallpaper selected yet."; return }
        wpStatus = "Extracting colors…"
        wpGot = false
        wpTry = 0
        wpErr = ""
        wpParseFail = ""
        runMatugen()
        mgCheck.restart()
    }

    // first try with every option, then with the bare minimum (older matugen versions)
    function runMatugen() {
        const img = Wallpaper.current
        const full = ["matugen", "image", img, "--source-color-index", "0", "--json", "hex", "--dry-run", "--type", wpScheme, "--mode", "dark"]
        const mini = ["matugen", "image", img, "--source-color-index", "0", "--json", "hex", "--dry-run"]
        mg.command = wpTry === 0 ? full : mini
        console.log("clover: " + mg.command.join(" "))
        mg.running = false
        mg.running = true
    }

    // matugen prints either {colors:{dark:{primary:"#.."}}} or {colors:{primary:{dark:"#.."}}} depending on version
    function norm(v) {
        if (typeof v === "string") return v.charAt(0) === "#" ? v : undefined
        if (v && typeof v === "object") {
            const order = ["dark", "default", "color", "hex", "light"]
            for (let i = 0; i < order.length; i++)
                if (v[order[i]] !== undefined) { const r = norm(v[order[i]]); if (r) return r }
        }
        return undefined
    }
    function findRole(node, role, depth) {
        if (!node || typeof node !== "object" || depth > 4) return undefined
        if (node[role] !== undefined) { const r = norm(node[role]); if (r) return r }
        const order = ["colors", "dark", "default", "light"]
        for (let i = 0; i < order.length; i++)
            if (node[order[i]] !== undefined) { const r = findRole(node[order[i]], role, depth + 1); if (r) return r }
        return undefined
    }

    function parseColors(text) {
        const a = text.indexOf("{"), b = text.lastIndexOf("}")
        if (a < 0 || b <= a) { wpParseFail = "matugen printed no JSON."; return }
        try {
            const d = JSON.parse(text.substring(a, b + 1))
            const val = role => findRole(d, role, 0)
            const alpha = (hex, aa) => "#" + aa + hex.substring(1, 7)
            const primary = val("primary")
            if (!primary) {
                wpParseFail = "Unrecognized matugen output (see qs log)."
                console.log("clover: matugen output was: " + text.substring(0, 500))
                return
            }
            const o = {
                accent: primary.substring(0, 7),
                accentDim: (val("primary_container") || primary).substring(0, 7),
                bg: alpha(val("surface_container_lowest") || val("surface") || val("background") || "#0a0a0a", "99"),
                line: alpha(val("outline_variant") || val("outline") || "#888888", "88"),
                text: (val("on_surface") || "#f5f5f5").substring(0, 7),
                dim: (val("on_surface_variant") || "#9a9a9a").substring(0, 7)
            }
            wpGot = true
            wp = o
            wpStatus = "Colors from " + Wallpaper.current.split("/").pop()
            mgCheck.stop()
            wpFile.setText(JSON.stringify(o, null, 2))
        } catch (e) {
            wpParseFail = "Could not read matugen output."
            console.log("clover: " + e + " in: " + text.substring(0, 300))
        }
    }

    // colors like "#aarrggbb" / "#rrggbb" -> "rgba(rrggbbaa)" for Hyprland borders
    function rgba(c) {
        const s = String(c)
        if (s.length === 9) return "rgba(" + s.substring(3) + s.substring(1, 3) + ")"
        return "rgba(" + s.substring(1) + "ff)"
    }
    function syncBorder() {
        Quickshell.execDetached(["hyprctl", "keyword", "general:col.active_border", rgba(Theme.accent)])
        Quickshell.execDetached(["hyprctl", "keyword", "general:col.inactive_border", rgba(Theme.line)])
    }
    onAccentChanged: borderTimer.restart()
    Timer { id: borderTimer; interval: 400; onTriggered: root.syncBorder() }

    Process {
        id: mg
        stdout: StdioCollector { onStreamFinished: root.parseColors(text) }
        stderr: StdioCollector { onStreamFinished: root.wpErr = text.trim().split("\n")[0] }
        onExited: exitCode => { root.wpExit = exitCode; decide.restart() }
    }
    property int wpExit: 0
    Timer {
        id: decide
        interval: 250
        onTriggered: {
            if (root.wpGot) return
            if (root.wpTry === 0) { root.wpTry = 1; root.runMatugen(); return }
            mgCheck.stop()
            root.wpStatus = root.wpParseFail !== "" ? root.wpParseFail
                : ("matugen failed (exit " + root.wpExit + ")" + (root.wpErr !== "" ? ": " + root.wpErr : ""))
        }
    }
    Timer {
        id: mgCheck
        interval: 12000
        onTriggered: if (root.wpStatus === "Extracting colors…") root.wpStatus = "matugen did not answer. Is it installed and in PATH?"
    }
    Connections {
        target: typeof Wallpaper !== "undefined" ? Wallpaper : null
        function onCurrentChanged() { if (root.preset === "wallpaper") root.refreshColors() }
    }

    FileView {
        id: wpFile
        path: root.dir + "/wallpaper-colors.json"
        onLoaded: {
            try { root.wp = JSON.parse(text()) } catch (e) { }
        }
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            const o = {}
            root.keys.forEach(k => { o[k] = root[k] })
            o.titlebars = Store.titlebars
            o.dnd = Notifs.dnd
            file.setText(JSON.stringify(o, null, 2))
        }
    }

    FileView {
        id: file
        path: root.path
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.keys.forEach(k => { if (d[k] !== undefined) root[k] = d[k] })
                if (d.cpuGauge === undefined && d.cat !== undefined) root.cpuGauge = d.cat      // old setting name
                if (d.titlebars !== undefined) Store.titlebars = d.titlebars
                if (d.dnd !== undefined) Notifs.dnd = d.dnd
            } catch (e) { }
        }
    }

    Connections { target: Store; function onTitlebarsChanged() { root.save() } }
    Connections { target: Notifs; function onDndChanged() { root.save() } }
}
