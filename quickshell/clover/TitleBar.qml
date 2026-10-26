import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// One pixel titlebar for one window, drawn as a layer surface just above the window.
// [app icon] [window name] ............ [v] [+] [□] [x]
PanelWindow {
    id: bar

    required property var tl                       // HyprlandToplevel
    readonly property var o: tl ? tl.lastIpcObject : null
    readonly property var wl: tl ? tl.wayland : null           // wlr toplevel (activate / close)
    readonly property var mon: tl ? tl.monitor : null
    readonly property var mo: mon ? mon.lastIpcObject : null
    readonly property int barH: 28
    readonly property int bw: 1        // must match general.border_size in look.lua
    readonly property bool active: wl ? wl.activated : false

    // ---- geometry in output-local logical px ----
    readonly property real scl: (mo && mo.scale) ? mo.scale : 1
    readonly property real mw: mo ? mo.width / scl : 0
    readonly property real x0: (o && o.at && mo) ? o.at[0] - mo.x : 0
    readonly property real y0: (o && o.at && mo) ? o.at[1] - mo.y : 0
    readonly property real x1: x0 + ((o && o.size) ? o.size[0] : 0)
    // the bar spans the window plus its border, so its sides line up with the window border
    readonly property real xl: Math.max(0, x0 - bw)
    readonly property real xr: Math.min(mw, x1 + bw)

    readonly property bool onScreen: {
        if (!o || !o.mapped || o.hidden || !o.at || !o.size || !mo) return false
        if (o.fullscreen > 0) return false
        const ws = o.workspace ? o.workspace.id : 0
        const sp = mo.specialWorkspace ? mo.specialWorkspace.id : 0
        if (ws < 0) return sp === ws
        if (sp !== 0) return false
        if (!mo.activeWorkspace || mo.activeWorkspace.id !== ws) return false
        return xr - xl > 60
    }

    visible: Store.titlebars && onScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    screen: Quickshell.screens.find(s => s.name === (mon ? mon.name : "")) ?? Quickshell.screens[0]
    anchors { left: true; top: true }
    margins.left: xl
    margins.top: Math.max(0, y0 - barH)
    implicitWidth: Math.max(1, xr - xl)
    implicitHeight: barH
    WlrLayershell.namespace: "clover-titlebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ---- title shown like a file name: NAME.EXT  window title ----
    function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    function extFor(id) {
        const n = id.toLowerCase()
        const has = list => list.some(k => n.indexOf(k) >= 0)
        if (has(["kitty", "alacritty", "foot", "wezterm", "konsole", "xterm", "gnome-terminal", "ghostty", "tilix", "terminator", "urxvt"])) return "sh"
        if (has(["nautilus", "thunar", "dolphin", "nemo", "pcmanfm", "ranger", "pavucontrol", "blueman", "nm-connection"])) return "dmg"
        if (has(["clover", "quickshell", "org.quickshell"])) return "app"
        if (has(["code", "vim", "emacs", "gedit", "kate", "zed", "sublime", "obsidian", "notes"])) return "txt"
        if (has(["mpv", "vlc", "celluloid", "totem", "obs"])) return "mp4"
        if (has(["imv", "feh", "eog", "gwenview", "krita", "gimp", "inkscape", "satty"])) return "png"
        if (has(["zathura", "evince", "okular", "foliate"])) return "pdf"
        return "bin"
    }

    readonly property string label: {
        const id = wl ? (wl.appId || "") : ""
        const parts = id.split(".")
        const name = ((parts.length > 2 ? parts[parts.length - 1] : id) || "window").toLowerCase()
        const ttl = tl ? tl.title : ""
        const extColor = active ? ("" + Theme.accent) : ("" + Theme.dim)
        let out = esc(name.toUpperCase()) + "<font color='" + extColor + "'>." + extFor(id).toUpperCase() + "</font>"
        if (ttl !== "" && ttl.toLowerCase() !== name) out += "  <font color='" + Theme.dim + "'>" + esc(ttl) + "</font>"
        return out
    }

    // window actions go through the active window (same dispatchers as your binds)
    property string pending: ""
    function viaActive(lua) {
        if (wl) wl.activate()
        pending = lua
        delay.restart()
    }
    Timer {
        id: delay
        interval: 70
        onTriggered: Quickshell.execDetached(["hyprctl", "dispatch", bar.pending])
    }

    readonly property var glyphs: ({
        min:  ["#.....#", ".#...#.", "..#.#..", "...#..."],
        max:  ["#######", "#######", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
        close: ["##...##", ".##.##.", "..###..", "...#...", "..###..", ".##.##.", "##...##"]
    })

    Item {
        anchors.fill: parent

        // one piece with the window: same border color on three sides, open at the bottom
        Rectangle {
            anchors.fill: parent
            color: bar.active ? Theme.accentDim : "#f20a0a0a"
        }
        Rectangle { x: 0; y: 0; width: parent.width; height: bar.bw; color: bar.active ? Theme.accent : Theme.line }
        Rectangle { x: 0; y: 0; width: bar.bw; height: parent.height; color: bar.active ? Theme.accent : Theme.line }
        Rectangle { x: parent.width - bar.bw; y: 0; width: bar.bw; height: parent.height; color: bar.active ? Theme.accent : Theme.line }

        MouseArea {
            anchors.fill: parent
            onClicked: if (bar.wl) bar.wl.activate()
        }

        IconImage {
            id: ic
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            source: Quickshell.iconPath(bar.wl ? bar.wl.appId : "", "application-x-executable")
        }

        Mono {
            anchors {
                left: ic.right; leftMargin: 8
                right: btns.left; rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: bar.label
            color: bar.active ? Theme.text : Theme.dim
            font.pixelSize: 10
            font.letterSpacing: 1
            font.weight: bar.active ? Font.Bold : Font.Normal
        }

        Row {
            id: btns
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 2

            Repeater {
                model: [
                    { g: "min",   lua: "hl.dsp.window.move({ workspace = \"special:magic\" })" },
                    { g: "max",   lua: "hl.dsp.window.fullscreen({ action = \"toggle\" })" },
                    { g: "close", lua: "" }
                ]
                delegate: Item {
                    id: b
                    required property var modelData
                    readonly property bool isClose: modelData.g === "close"
                    width: 26
                    height: 20

                    Bevel {
                        anchors.fill: parent
                        down: ba.pressed
                        fill: ba.containsMouse ? (b.isClose ? Theme.accent : "#26ffffff") : "transparent"
                        edge: ba.containsMouse && b.isClose ? Theme.accent : Theme.line
                    }
                    Pix {
                        anchors.centerIn: parent
                        rows: bar.glyphs[b.modelData.g]
                        tone: Theme.text
                    }
                    MouseArea {
                        id: ba
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (b.isClose) { if (bar.wl) bar.wl.close() }
                            else bar.viaActive(b.modelData.lua)
                        }
                    }
                }
            }
        }
    }
}
