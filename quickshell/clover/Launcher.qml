import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// App launcher: search on top, pinned grid, recommended list, user/power footer.
// Toggle: qs -c clover ipc call clover launcher   (also START -> Programs…)
// Right-click an app to pin / unpin it. Type digits and operators for a quick calculator (Enter copies).
PanelWindow {
    id: win

    readonly property bool open: Store.launcherOpen && Hyprland.focusedMonitor?.name === screen?.name
    readonly property int barH: 48     // taskbar height, kept clear so START still works
    readonly property int cols: 6
    readonly property string user: Settings.displayName

    property bool allMode: false
    property int sel: 0
    property string armed: ""

    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    margins.bottom: barH
    WlrLayershell.namespace: "clover-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------- data ----------
    function score(a, q) {
        if (q === "") return 1
        const n = (a.name || "").toLowerCase()
        if (n.startsWith(q)) return 100
        if (n.includes(q)) return 80
        const kw = ((a.genericName || "") + " " + Array.from(a.keywords || []).join(" ")).toLowerCase()
        if (kw.includes(q)) return 50
        if ((a.comment || "").toLowerCase().includes(q)) return 30
        return 0
    }

    function launch(a) {
        if (!a) return
        Store.bumpApp(a.id)
        a.execute()
        Store.launcherOpen = false
    }

    readonly property bool searching: input.text.trim() !== ""
    readonly property bool browse: searching || allMode

    readonly property var results: {
        const q = input.text.trim().toLowerCase()
        const apps = DesktopEntries.applications.values
        const out = []
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i]
            if (a.noDisplay) continue
            const s = win.score(a, q)
            if (s > 0) out.push({ a: a, s: s })
        }
        out.sort((x, y) => (y.s - x.s) || x.a.name.localeCompare(y.a.name))
        return out.map(o => o.a)
    }

    readonly property var mostUsed: {
        const u = Store.appUsage
        const apps = DesktopEntries.applications.values
        const arr = []
        for (let i = 0; i < apps.length; i++)
            if (!apps[i].noDisplay && (u[apps[i].id] || 0) > 0) arr.push(apps[i])
        arr.sort((x, y) => (u[y.id] - u[x.id]) || x.name.localeCompare(y.name))
        return arr
    }

    readonly property bool usePins: Store.appPinned.length > 0

    readonly property var gridApps: {
        if (browse) return results
        const byId = {}
        const apps = DesktopEntries.applications.values
        for (let i = 0; i < apps.length; i++) if (!apps[i].noDisplay) byId[apps[i].id] = apps[i]
        if (usePins) return Store.appPinned.map(id => byId[id]).filter(a => a).slice(0, 18)
        const out = mostUsed.slice(0, 18)
        for (let i = 0; i < results.length && out.length < 18; i++)
            if (out.indexOf(results[i]) < 0) out.push(results[i])
        return out
    }

    // recommended: most used, then fill with whatever is left
    readonly property var recApps: {
        const out = mostUsed.slice(0, 6)
        for (let i = 0; i < results.length && out.length < 6; i++)
            if (out.indexOf(results[i]) < 0) out.push(results[i])
        return out
    }

    readonly property string calcOut: {
        const q = input.text.trim()
        if (!/^[\d\s+\-*\/().%^]+$/.test(q) || !/[+\-*\/%^]/.test(q.replace(/^-/, ""))) return ""
        try {
            const v = eval(q.replace(/\^/g, "**"))
            return (typeof v === "number" && isFinite(v)) ? String(Math.round(v * 1e9) / 1e9) : ""
        } catch (e) { return "" }
    }

    readonly property string title: calcOut !== "" ? "= " + calcOut
        : searching ? "RESULTS"
        : allMode ? "ALL APPS"
        : usePins ? "PINNED" : "SUGGESTED"
    readonly property string titleHint: calcOut !== "" ? "ENTER COPIES"
        : (!browse && !usePins) ? "RIGHT-CLICK AN APP TO PIN IT" : ""

    function move(d) {
        if (gridApps.length === 0) return
        sel = Math.max(0, Math.min(gridApps.length - 1, sel + d))
        grid.positionViewAtIndex(sel, GridView.Contain)
    }

    function power(act) {
        if (armed !== act) { armed = act; return }
        armed = ""
        Store.launcherOpen = false
        if (act === "lock") Quickshell.execDetached(["qs", "-c", "lock"])
        else if (act === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (act === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
    }

    onOpenChanged: {
        if (open) {
            input.text = Store.launcherSeed
            Store.launcherSeed = ""
            allMode = false
            sel = 0
            armed = ""
            input.forceActiveFocus()
            input.cursorPosition = input.text.length
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Store.launcherOpen = false
    }

    Item {
        id: wrap
        anchors { left: parent.left; bottom: parent.bottom }
        width: 572
        height: 610

        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        // hard pixel shadow (right + bottom)
        Rectangle { x: parent.width; y: 2; width: 2; height: parent.height; color: "#66000000" }
        Rectangle { x: 2; y: parent.height; width: parent.width; height: 2; color: "#66000000" }

        Bevel {
            anchors.fill: parent
            fill: Theme.bg
            edge: Theme.accent
        }

        // ---- search (top) ----
        Item {
            x: 16
            y: 14
            width: 540
            height: 34

            Bevel { anchors.fill: parent; down: true; fill: "#59000000" }
            Pix {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                rows: Icons.bm.search
                palette: Icons.pal.search
            }
            Mono {
                visible: input.text === ""
                anchors { left: parent.left; leftMargin: 42; verticalCenter: parent.verticalCenter }
                text: "APPLICATIONS, 2+2…"
                color: Theme.dim
                font.pixelSize: 11
                font.letterSpacing: 1.5
            }
            TextInput {
                id: input
                anchors { left: parent.left; leftMargin: 42; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                font.family: Theme.mono
                font.pixelSize: 12
                color: Theme.text
                selectionColor: Theme.accentDim
                clip: true
                focus: true

                onTextChanged: { win.sel = 0; grid.positionViewAtBeginning() }

                Keys.onEscapePressed: {
                    if (win.searching) input.text = ""
                    else if (win.allMode) win.allMode = false
                    else Store.launcherOpen = false
                }
                // Super+Space closes it even if the compositor forwards the key instead of firing the bind
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space && (event.modifiers & Qt.MetaModifier)) {
                        Store.launcherOpen = false
                        event.accepted = true
                    }
                }
                Keys.onReturnPressed: win.accept()
                Keys.onEnterPressed: win.accept()
                Keys.onLeftPressed: win.move(-1)
                Keys.onRightPressed: win.move(1)
                Keys.onUpPressed: win.move(-win.cols)
                Keys.onDownPressed: win.move(win.cols)
                Keys.onTabPressed: win.move(1)
            }
        }

        // ---- section header ----
        Item {
            x: 16
            y: 58
            width: 540
            height: 26

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.title
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 3
                }
                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.titleHint
                    color: Theme.dim
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                }
            }

            // ALL APPS > / < BACK
            Item {
                visible: !win.searching
                anchors.right: parent.right
                width: 98
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Bevel {
                    anchors.fill: parent
                    down: ba.pressed
                    fill: ba.containsMouse ? "#14ffffff" : "transparent"
                }
                Mono {
                    anchors.centerIn: parent
                    text: win.allMode ? "< BACK" : "ALL APPS >"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                MouseArea {
                    id: ba
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { win.allMode = !win.allMode; win.sel = 0; grid.positionViewAtBeginning() }
                }
            }
        }

        // ---- app grid ----
        GridView {
            id: grid
            x: 16
            y: 88
            width: 540
            height: win.browse ? 462 : 288
            clip: true
            cellWidth: 90
            cellHeight: 96
            model: win.gridApps
            interactive: win.browse
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property bool pinned: Store.appPinned.indexOf(modelData.id) >= 0

                Item {
                    anchors { fill: parent; margins: 3 }

                    Bevel {
                        anchors.fill: parent
                        visible: win.sel === tile.index
                        down: ta.pressed
                        fill: "#14ffffff"
                        edge: Theme.accent
                    }
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 12
                        implicitSize: 36
                        source: Quickshell.iconPath(tile.modelData.icon, "application-x-executable")
                    }
                    Mono {
                        x: 4
                        y: 56
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: tile.modelData.name.toUpperCase()
                        color: win.sel === tile.index ? Theme.text : Theme.dim
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                    }
                    // pin marker (shown where the grid is not the pinned view)
                    Rectangle {
                        visible: tile.pinned && (win.browse || !win.usePins)
                        x: parent.width - 8
                        y: 4
                        width: 4
                        height: 4
                        color: Theme.accent
                    }
                    MouseArea {
                        id: ta
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: win.sel = tile.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) Store.togglePin(tile.modelData.id)
                            else win.launch(tile.modelData)
                        }
                    }
                }
            }
        }

        // ---- recommended ----
        Item {
            visible: !win.browse
            x: 16
            y: 384
            width: 540
            height: 160

            Mono {
                text: "RECOMMENDED"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.letterSpacing: 3
            }

            Grid {
                y: 28
                columns: 2
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: win.recApps
                    delegate: Item {
                        id: rec
                        required property var modelData
                        width: 270
                        height: 44

                        Bevel {
                            anchors { fill: parent; margins: 2 }
                            visible: ra.containsMouse
                            down: ra.pressed
                            fill: "#14ffffff"
                            edge: Theme.accentDim
                        }
                        IconImage {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 28
                            source: Quickshell.iconPath(rec.modelData.icon, "application-x-executable")
                        }
                        Column {
                            anchors { left: parent.left; leftMargin: 52; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Mono {
                                width: parent.width
                                elide: Text.ElideRight
                                text: rec.modelData.name.toUpperCase()
                                font.pixelSize: 10
                                font.letterSpacing: 1
                            }
                            Mono {
                                width: parent.width
                                elide: Text.ElideRight
                                text: (rec.modelData.comment || rec.modelData.genericName || "").toLowerCase()
                                color: Theme.dim
                                font.pixelSize: 9
                            }
                        }
                        MouseArea {
                            id: ra
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.launch(rec.modelData)
                        }
                    }
                }
            }
        }

        // ---- footer: user + power ----
        Rectangle { x: 8; y: parent.height - 3 - 46 - 1; width: parent.width - 16; height: 1; color: Theme.line }
        Item {
            x: 16
            y: parent.height - 3 - 46
            width: 540
            height: 46

            Item {
                visible: Settings.pixelAvatar
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
                x: Settings.pixelAvatar ? 46 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: win.user.toUpperCase()
                font.pixelSize: 11
                font.letterSpacing: 2
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6

                Mono {
                    visible: win.armed !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CLICK AGAIN TO CONFIRM"
                    color: Theme.accent
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: [
                        { icon: "lock",    act: "lock" },
                        { icon: "restart", act: "reboot" },
                        { icon: "power",   act: "poweroff" }
                    ]
                    delegate: Item {
                        id: pb
                        required property var modelData
                        width: 34
                        height: 34

                        Bevel {
                            anchors.fill: parent
                            down: pa.pressed
                            fill: win.armed === pb.modelData.act ? Theme.accentDim : (pa.containsMouse ? "#14ffffff" : "transparent")
                            edge: win.armed === pb.modelData.act ? Theme.accent : Theme.line
                        }
                        Pix {
                            anchors.centerIn: parent
                            rows: Icons.bm[pb.modelData.icon]
                            palette: Icons.pal[pb.modelData.icon]
                        }
                        MouseArea {
                            id: pa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: win.power(pb.modelData.act)
                        }
                    }
                }
            }
        }
    }

    function accept() {
        if (calcOut !== "") {
            Quickshell.execDetached(["wl-copy", calcOut])
            Store.launcherOpen = false
            return
        }
        launch(gridApps[sel])
    }
}
