pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent user settings (settings.json next to the other Clover files).
// Edited from SettingsApp.qml; other components just read these properties.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/quickshell/clover/settings.json"

    property string preset: "orange"
    property bool clock24: true
    property bool cat: true
    property bool reduceMotion: false
    property bool highContrast: false
    property bool pixelAvatar: true
    property string userName: ""
    property string termCmd: "kitty"
    property string filesCmd: "nautilus"
    property int popupSec: 6

    readonly property var presets: ({
        orange: { name: "Orange", accent: "#ff7a18", dim: "#8a3d0a" },
        amber:  { name: "Amber",  accent: "#ffb000", dim: "#6e4c00" },
        ember:  { name: "Ember",  accent: "#ff4d00", dim: "#7a2500" },
        white:  { name: "White",  accent: "#f5f5f5", dim: "#55555a" }
    })
    readonly property var presetIds: ["orange", "amber", "ember", "white"]
    readonly property color accent: presets[preset] ? presets[preset].accent : "#ff7a18"
    readonly property color accentDim: presets[preset] ? presets[preset].dim : "#8a3d0a"
    readonly property string displayName: userName !== "" ? userName : (Quickshell.env("USER") || "user")

    // keys that are stored in the file
    readonly property var keys: ["preset", "clock24", "cat", "reduceMotion", "highContrast", "pixelAvatar", "userName", "termCmd", "filesCmd", "popupSec"]

    function set(key, value) {
        root[key] = value
        save()
    }
    function save() { saveTimer.restart() }
    function reload() { file.reload() }

    // bundles used by the Presets page
    function applyBundle(id) {
        if (presets[id]) { preset = id }
        else if (id === "minimal") { cat = false; reduceMotion = true; Store.titlebars = false }
        else if (id === "full") { cat = true; reduceMotion = false; Store.titlebars = true }
        save()
    }

    function resetAll() {
        preset = "orange"; clock24 = true; cat = true; reduceMotion = false; highContrast = false
        pixelAvatar = true; userName = ""; termCmd = "kitty"; filesCmd = "nautilus"; popupSec = 6
        Store.titlebars = true
        Notifs.dnd = false
        save()
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
                if (d.titlebars !== undefined) Store.titlebars = d.titlebars
                if (d.dnd !== undefined) Notifs.dnd = d.dnd
            } catch (e) { }
        }
    }

    Connections { target: Store; function onTitlebarsChanged() { root.save() } }
    Connections { target: Notifs; function onDndChanged() { root.save() } }
}
