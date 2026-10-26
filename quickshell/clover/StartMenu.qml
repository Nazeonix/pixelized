import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// START button menu. Toggle: qs -c clover ipc call clover start
// Type anything to jump into the launcher with that text.
PanelWindow {
    id: win

    readonly property bool open: Store.startOpen && Hyprland.focusedMonitor?.name === screen?.name
    readonly property int barH: 48
    readonly property int rowH: 30
    readonly property string user: Settings.displayName

    property int cur: 0
    property string armed: ""     // power action waiting for a second click

    readonly property var items: [
        { icon: "search", label: "Programs…",    hint: "Super+Space",   act: "programs" },
        { icon: "term",   label: "Terminal",     hint: "",              act: "term" },
        { icon: "folder", label: "Files",        hint: "Super+E",       act: "files" },
        { sep: true },
        { icon: "image",  label: "Wallpaper",    hint: "Super+Shift+W", act: "wall" },
        { icon: "gear",   label: "Edit desktop", hint: "Super+A",       act: "edit" },
        { icon: "eye",    label: "Hide widgets", hint: "Super+H",       act: "hide" },
        { icon: "note",   label: "Notes",        hint: "Super+N",       act: "notes" },
        { sep: true },
        { icon: "sliders", label: "Settings",    hint: "",              act: "settings" },
        { sep: true },
        { icon: "lock",    label: "Lock",        hint: "Super+L",       act: "lock" },
        { icon: "logout",  label: "Log out",     hint: "",              act: "logout",   confirm: true },
        { icon: "restart", label: "Restart…",    hint: "",              act: "reboot",   confirm: true },
        { icon: "power",   label: "Shut down…",  hint: "",              act: "poweroff", confirm: true }
    ]
    readonly property int listH: items.reduce((h, it) => h + (it.sep ? 10 : rowH), 0)

    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    margins.bottom: barH
    WlrLayershell.namespace: "clover-start"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function step(d) {
        let i = cur
        for (let n = 0; n < items.length; n++) {
            i = (i + d + items.length) % items.length
            if (!items[i].sep) { cur = i; armed = ""; return }
        }
    }

    function run(it) {
        if (!it || it.sep) return
        if (it.confirm && armed !== it.act) { armed = it.act; return }
        armed = ""
        Store.startOpen = false
        switch (it.act) {
        case "programs": Store.launcherOpen = true; break
        case "term":     Quickshell.execDetached(Settings.termCmd.trim().split(/\s+/)); break
        case "files":    Quickshell.execDetached(Settings.filesCmd.trim().split(/\s+/)); break
        case "settings": Store.settingsOpen = true; break
        case "wall":     Wallpaper.random(); break
        case "edit":     Store.editing = true; break
        case "hide":     Store.hidden = !Store.hidden; break
        case "notes":    Store.toggleType("notes"); break
        case "lock":     Quickshell.execDetached(["qs", "-c", "lock"]); break
        case "logout":   Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]); break
        case "reboot":   Quickshell.execDetached(["systemctl", "reboot"]); break
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break
        }
    }

    onOpenChanged: {
        if (open) {
            cur = 0
            armed = ""
            keys.forceActiveFocus()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: Store.startOpen = false }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) Store.startOpen = false
            else if (event.key === Qt.Key_Up) win.step(-1)
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) win.step(1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.run(win.items[win.cur])
            else if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                // typing = search
                Store.launcherSeed = event.text
                Store.launcherOpen = true
            } else return
            event.accepted = true
        }
    }

    Item {
        id: wrap
        anchors { left: parent.left; bottom: parent.bottom }
        width: 310
        height: 3 + 46 + 1 + win.listH + 1 + 28 + 3

        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        // hard pixel shadow
        Rectangle { x: parent.width; y: 2; width: 2; height: parent.height; color: "#66000000" }
        Rectangle { x: 2; y: parent.height; width: parent.width; height: 2; color: "#66000000" }

        Bevel {
            anchors.fill: parent
            fill: Theme.bg
            edge: Theme.accent
        }

        // user header
        Item {
            id: head
            x: 3
            y: 3
            width: parent.width - 6
            height: 46

            Item {
                visible: Settings.pixelAvatar
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                Bevel { anchors.fill: parent; down: true; fill: "#59000000"; edge: Theme.accentDim }
                Pix {
                    anchors.centerIn: parent
                    rows: Icons.bm.heart
                    palette: Icons.pal.heart
                }
            }
            Mono {
                x: Settings.pixelAvatar ? 52 : 12
                anchors.verticalCenter: parent.verticalCenter
                text: win.user.toUpperCase()
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 2
            }
        }
        Rectangle { x: 8; y: 49; width: parent.width - 16; height: 1; color: Theme.line }

        // entries
        Column {
            id: col
            x: 3
            y: 51
            width: parent.width - 6

            Repeater {
                model: win.items
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: !modelData.sep && win.cur === index
                    readonly property bool arm: !modelData.sep && win.armed === modelData.act

                    width: col.width
                    height: modelData.sep ? 10 : win.rowH

                    Rectangle {
                        visible: row.modelData.sep === true
                        x: 5
                        y: 5
                        width: parent.width - 10
                        height: 1
                        color: Theme.line
                    }

                    Item {
                        visible: row.modelData.sep !== true
                        anchors.fill: parent

                        Rectangle {
                            anchors.fill: parent
                            color: row.arm ? Theme.accentDim : (row.sel ? Theme.accent : "transparent")
                        }
                        Pix {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            rows: row.modelData.icon ? Icons.bm[row.modelData.icon] : []
                            palette: row.modelData.icon ? Icons.pal[row.modelData.icon] : ({})
                        }
                        Mono {
                            x: 44
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.arm ? "CLICK AGAIN TO CONFIRM" : (row.modelData.label || "").toUpperCase()
                            color: Theme.text
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            font.weight: row.sel || row.arm ? Font.Bold : Font.Normal
                        }
                        Mono {
                            visible: !row.arm
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: (row.modelData.hint || "").toUpperCase()
                            color: row.sel ? Theme.text : Theme.dim
                            font.pixelSize: 8
                            font.letterSpacing: 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: { win.cur = row.index; if (win.armed !== row.modelData.act) win.armed = "" }
                            onClicked: win.run(row.modelData)
                        }
                    }
                }
            }
        }

        // footer hint
        Rectangle { x: 8; y: parent.height - 3 - 28 - 1; width: parent.width - 16; height: 1; color: Theme.line }
        Item {
            x: 3
            y: parent.height - 3 - 28
            width: parent.width - 6
            height: 28

            Row {
                anchors.centerIn: parent
                spacing: 6
                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TYPE TO SEARCH"
                    color: Theme.dim
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }
                Pix {
                    anchors.verticalCenter: parent.verticalCenter
                    px: 1
                    rows: Icons.bm.heart
                    palette: Icons.pal.heart
                }
            }
        }
    }
}
