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
    readonly property var o: tl.lastIpcObject
    readonly property var wl: tl.wayland           // wlr toplevel (activate / close)
    readonly property var mon: tl.monitor
    readonly property var mo: mon ? mon.lastIpcObject : null
    readonly property int barH: 28
    readonly property bool active: wl ? wl.activated : false

    // ---- geometry in output-local logical px ----
    readonly property real scl: (mo && mo.scale) ? mo.scale : 1
    readonly property real mw: mo ? mo.width / scl : 0
    readonly property real x0: (o && o.at && mo) ? o.at[0] - mo.x : 0
    readonly property real y0: (o && o.at && mo) ? o.at[1] - mo.y : 0
    readonly property real x1: x0 + ((o && o.size) ? o.size[0] : 0)
    readonly property real left: Math.max(0, x0)
    readonly property real right: Math.min(mw, x1)

    readonly property bool onScreen: {
        if (!o || !o.mapped || o.hidden || !o.at || !o.size || !mo) return false
        if (o.fullscreen > 0) return false
        const ws = o.workspace ? o.workspace.id : 0
        const sp = mo.specialWorkspace ? mo.specialWorkspace.id : 0
        if (ws < 0) return sp === ws
        if (sp !== 0) return false
        if (!mo.activeWorkspace || mo.activeWorkspace.id !== ws) return false
        return right - left > 60
    }

    visible: Store.titlebars && onScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    screen: Quickshell.screens.find(s => s.name === (mon ? mon.name : "")) ?? Quickshell.screens[0]
    anchors { left: true; top: true }
    margins.left: left
    margins.top: Math.max(0, y0 - barH)
    implicitWidth: Math.max(1, right - left)
    implicitHeight: barH
    WlrLayershell.namespace: "clover-titlebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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
        plus: ["..#..", "..#..", "#####", "..#..", "..#.."],
        max:  ["#######", "#######", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
        close: ["##...##", ".##.##.", "..###..", "...#...", "..###..", ".##.##.", "##...##"]
    })

    Item {
        anchors.fill: parent

        Bevel {
            anchors.fill: parent
            fill: bar.active ? Theme.accentDim : "#d90a0a0a"
            edge: bar.active ? Theme.accent : Theme.line
        }

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
            text: (bar.tl.title !== "" ? bar.tl.title : (bar.wl ? bar.wl.appId : "")).toUpperCase()
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
                    { g: "plus",  lua: "hl.dsp.window.float({ action = \"toggle\" })" },
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
