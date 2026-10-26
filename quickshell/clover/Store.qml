pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property bool editing: false
    property bool hidden: false     // focus mode
    property bool launcherOpen: false
    property bool settingsOpen: false      // settings window
    property string settingsQuery: ""     // settings search text (lowercase)
    property bool notifCenter: false       // notification history panel
    property bool titlebars: true          // pixel window titlebars
    property bool startOpen: false          // START button menu
    property string launcherSeed: ""        // text typed in the start menu, handed to the launcher
    onLauncherOpenChanged: if (launcherOpen) startOpen = false
    onStartOpenChanged: if (startOpen) launcherOpen = false

    // launcher: launch counts + pinned apps (persisted to apps.json)
    property var appUsage: ({})
    property var appPinned: []
    function bumpApp(id) {
        const u = Object.assign({}, appUsage)
        u[id] = (u[id] || 0) + 1
        appUsage = u
        appsTimer.restart()
    }
    function clearApps() {
        appPinned = []
        appUsage = {}
        appsTimer.restart()
    }
    function togglePin(id) {
        appPinned = appPinned.indexOf(id) >= 0 ? appPinned.filter(x => x !== id) : appPinned.concat([id])
        appsTimer.restart()
    }
    Timer {
        id: appsTimer
        interval: 500
        onTriggered: appsFile.setText(JSON.stringify({ usage: root.appUsage, pinned: root.appPinned }, null, 2))
    }
    FileView {
        id: appsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/clover/apps.json"
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.appUsage = d.usage || {}
                root.appPinned = d.pinned || []
            } catch (e) { }
        }
    }

    // alt-tab: most-recently-used window order + switcher state
    property var mru: []
    property bool altOpen: false
    property int altIndex: 0
    property var altList: []
    property var hiddenTypes: ({})  // {type: true} hidden via ipc `clover toggle <type>`
    property var items: defaults    // [{id,type,scope,x,y,w,h,pinned}]

    readonly property int grid: 20
    readonly property var sizes: ({
        clock: [260, 130], media: [480, 190], sys: [260, 130], workspaces: [200, 52], notes: [420, 260], wallpaper: [340, 230]
    })
    readonly property var defaults: [
        { id: "clock-0",      type: "clock",      scope: "global", x: 40, y: 40,  w: 260, h: 130, pinned: false },
        { id: "workspaces-0", type: "workspaces", scope: "global", x: 40, y: 190, w: 200, h: 52,  pinned: false },
        { id: "media-0",      type: "media",      scope: 1,        x: 40, y: 262, w: 480, h: 190, pinned: false },
        { id: "sys-0",        type: "sys",        scope: 2,        x: 40, y: 262, w: 260, h: 130, pinned: false },
        { id: "notes-0",      type: "notes",      scope: "global", corner: "br", x: 40, y: 60, w: 420, h: 260, pinned: false }
    ]

    function idsFor(ws) {
        return items.filter(i => i.scope === "global" || i.scope === ws).map(i => i.id)
    }
    function touch(t) {
        if (!t) return
        mru = [t].concat(mru.filter(x => x !== t))
    }
    function windows() {
        const all = Array.from(ToplevelManager.toplevels.values)
        const out = mru.filter(t => all.indexOf(t) >= 0)
        all.forEach(t => { if (out.indexOf(t) < 0) out.push(t) })
        return out
    }
    function altStep(d) {
        if (!altOpen) {
            const l = windows()
            if (l.length === 0) return
            altList = l
            altIndex = l.length > 1 ? (d > 0 ? 1 : l.length - 1) : 0
            altOpen = true
        } else {
            const n = altList.length
            altIndex = (altIndex + d + n) % n
        }
    }
    function altCommit() {
        if (!altOpen) return
        const t = altList[altIndex]
        altOpen = false
        if (t) t.activate()
    }
    function altCancel() { altOpen = false }
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { root.touch(ToplevelManager.activeToplevel) }
    }

    function toggleType(t) {
        const h = Object.assign({}, hiddenTypes)
        h[t] = !h[t]
        hiddenTypes = h
    }
    function find(id) {
        return items.find(i => i.id === id) ?? null
    }
    function patch(id, p) {
        items = items.map(i => i.id === id ? Object.assign({}, i, p) : i)
        saveTimer.restart()
    }
    function add(type, ws) {
        const s = sizes[type]
        if (!s) return
        const id = type + "-" + Date.now().toString(36)
        items = items.concat([{ id: id, type: type, scope: ws, x: 80, y: 80, w: s[0], h: s[1], pinned: false }])
        saveTimer.restart()
    }
    // move every widget of a type to a corner ("tl" or "br"), 40px from the sides, 60px from top/bottom (clears the bar)
    function dock(type, corner) {
        items = items.map(i => i.type === type ? Object.assign({}, i, { corner: corner, x: 40, y: 60 }) : i)
        saveTimer.restart()
    }
    function remove(id) {
        items = items.filter(i => i.id !== id)
        saveTimer.restart()
    }
    function toggleScope(id, ws) {
        const c = find(id)
        if (c) patch(id, { scope: c.scope === "global" ? ws : "global" })
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: file.setText(JSON.stringify(root.items, null, 2))
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell/clover/layout.json"
        onLoaded: {
            try { root.items = JSON.parse(text()) } catch (e) { }
        }
    }
}
