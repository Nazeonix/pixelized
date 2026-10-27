import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Win98/XP-style taskbar, terminal skin, pixel edges, zero rounding.
// [START] ::: task buttons ............ [tray  HH:MM]
// START toggles the launcher. Task: left = focus, middle = close.
PanelWindow {
    id: win

    visible: !Store.hidden
    color: "transparent"
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.namespace: "clover-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { left: true; right: true; bottom: true }
    implicitHeight: 48

    property string layout: "EN"
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property real vol: audio ? audio.volume : 0

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat ? bat.isPresent : false
    readonly property int batPct: bat ? Math.round(bat.percentage <= 1 ? bat.percentage * 100 : bat.percentage) : 0
    readonly property bool charging: bat ? bat.state === UPowerDeviceState.Charging : false
    readonly property bool discharging: bat ? bat.state === UPowerDeviceState.Discharging : false

    readonly property var bmSpeaker: [
        "...#.....",
        "..##..#..",
        "####...#.",
        "####...#.",
        "####...#.",
        "..##..#..",
        "...#....."
    ]
    readonly property var bmMute: [
        "...#.....",
        "..##.....",
        "####.#..#",
        "####..##.",
        "####..##.",
        "..##.#..#",
        "...#....."
    ]
    readonly property var bmBell: [
        "....#....",
        "...###...",
        "..#####..",
        "..#####..",
        "..#####..",
        ".#######.",
        "#########",
        "....#...."
    ]

    readonly property var tubePalette: ({
        "A": "#f0f0f0", "e": "#2a2a30", "W": "#4a4a52", "t": "#9a9a96",
        "r": "#f00030", "y": "#f0c000", "g": "#48c018",
        "R": "#ff7088", "Y": "#fff070", "G": "#8ae868"      // lighter shades: glass glint + liquid surface
    })

    // 9x16 pixel test tube: liquid fills bottom-up (red, yellow, green), rim, rounded bottom,
    // measuring ticks, glass glint, shiny liquid surface, pixel bolt when charging
    function batRows(pct, charging) {
        const t = [
            "AAAAAAAAA",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            ".AeeeeeA.",
            "..AeeeA..",
            "...AAA..."
        ]
        const rowsOf = []                                   // slot rows, bottom -> top
        for (let y = 14; y >= 1; y--) rowsOf.push(y)
        const n = pct > 0 ? Math.ceil(pct / 100 * rowsOf.length) : 0
        const r = t.map(s => s.split(""))
        rowsOf.forEach((y, i) => {
            if (i >= n) return
            const ch = i < 5 ? "r" : (i < 10 ? "y" : "g")
            for (let x = 0; x < 9; x++) if (r[y][x] === "e") r[y][x] = ch
        })
        const light = { r: "R", y: "Y", g: "G", e: "W" }
        // liquid surface
        if (n > 0) {
            const ys = rowsOf[n - 1]
            for (let x = 0; x < 9; x++) if (light[r[ys][x]] && r[ys][x] !== "e") r[ys][x] = light[r[ys][x]]
        }
        // glass glint (left side)
        for (let y = 2; y <= 8; y++) if (light[r[y][3]]) r[y][3] = light[r[y][3]]
        // measuring ticks at ~25 / 50 / 75 %
        for (const i of [3, 6, 10]) {
            const y = rowsOf[i]
            if (r[y][2] === "e" || r[y][2] === "r" || r[y][2] === "y" || r[y][2] === "g" || r[y][2] === "W") r[y][2] = "t"
        }
        if (charging) {
            const bolt = ["..+", ".+.", "+++", ".+.", "+.."]
            for (let i = 0; i < bolt.length; i++)
                for (let j = 0; j < bolt[i].length; j++)
                    if (bolt[i][j] === "+") r[5 + i][3 + j] = "+"
        }
        return r.map(a => a.join(""))
    }

    // ---- cpu cat: sleeps when idle, runs faster the busier the cpu is ----
    property real cpu: 0          // smoothed 0..1
    property bool catAwake: false
    property int catFrame: 0
    property int sleepFrame: 0
    property real _tot: 0
    property real _idle: 0
    readonly property int catInterval: Math.round(Math.max(40, 150 - cpu * 110))

    readonly property var catPalette: ({
        "o": "#4a2410", "p": "#ff7a18", "l": "#ffc48a", "d": "#c4560a",
        "e": "#201008", "w": "#ffffff", "n": "#ffb27a", "h": "#f5f5f5"
    })
    // 24x14 sprites: two breathing frames when asleep, six run frames
    readonly property var catSleep: [
[
            "........................",
            "........................",
            "...............o...o....",
            "..............opo.opo...",
            "......ooooooooonpopno...",
            "...oooppdppdpppppppppo..",
            "..oppdppdppdppppppppppo.",
            ".opppppppppppppppppeepoo",
            ".opppppppppppppppppplnoh",
            ".opppppppppppppppppplloo",
            "..oppppppppppppppppppooh",
            "...ooddddddddddplllllo.o",
            ".....oooooooooooooooo...",
            "........................"
        ],
[
            "........................",
            "........................",
            "...............o...o....",
            ".......oooooooopooopo...",
            "....oooppppppppnpppno...",
            "...opdppdppdpppppppppo..",
            "..oppdppdppdppppppppppo.",
            ".opppppppppppppppppeepoo",
            ".opppppppppppppppppplnoh",
            ".opppppppppppppppppplloo",
            "..oppppppppppppppppppooh",
            "...ooddddddddddplllllo.o",
            ".....oooooppppooooooo...",
            "..........oooo.........."
        ]
    ]
    readonly property var catRun: [
[
            "..o............o...o....",
            ".opo..........opo.opo...",
            "opo...........onpopno...",
            "opo..oooooooooooppppo...",
            ".opoopdppdppdppppppwpo..",
            "..oppppppppppppppppeppoo",
            "..oppppppppppppppppplnoh",
            "..oppppppppppplppppplloo",
            "...oppppppppppllppppoooh",
            "....olllllllllllpooo...o",
            "...oddppooooooddppo.....",
            "..oddoppo.....odppo.....",
            ".ollollo.......olllo....",
            "..oo.oo.........ooo....."
        ],
[
            "........................",
            ".o.............o...o....",
            "opo...........opo.opo...",
            "opo...........onpopno...",
            "opo..oooooooooooppppo...",
            "opooopdppdppdppppppwpo..",
            ".opppppppppppppppppeppoo",
            "..oppppppppppppppppplnoh",
            "..oppppppppppplppppplloo",
            "...oppppppppppllppppoooh",
            "....olllllllllllpooo...o",
            "...oddppooooooddppo.....",
            "...ollllo....ollllo.....",
            "....oooo......oooo......"
        ],
[
            "...............o...o....",
            "..o...........opo.opo...",
            ".opo..........onpopno...",
            "opo..oooooooooooppppo...",
            "opo.opdppdppdppppppwpo..",
            "oppopppppppppppppppeppoo",
            ".ooppppppppppppppppplnoh",
            "..oppppppppppplppppplloo",
            "...oppppppppppllppppoooh",
            "....olllllllllllpooo...o",
            "....oddppooooddppo......",
            "....oddppo..oddppo......",
            "....ollllo..ollllo......",
            ".....oooo....oooo......."
        ],
[
            ".o.............o...o....",
            "opo...........opo.opo...",
            "opo...........onpopno...",
            "opo..oooooooooooppppo...",
            "opooopdppdppdppppppwpo..",
            ".opppppppppppppppppeppoo",
            "..oppppppppppppppppplnoh",
            "..oppppppppppplppppplloo",
            "...oppppppppppllppppoooh",
            "....olllllllllllpooo...o",
            ".....oddppooddppo.......",
            "......odppoddoppo.......",
            ".......ollllollo........",
            "........oooo.oo........."
        ],
[
            "........................",
            "..o............o...o....",
            ".opo..........opo.opo...",
            "opo...........onpopno...",
            "opo..oooooooooooppppo...",
            ".opoopdppdppdppppppwpo..",
            "..oppppppppppppppppeppoo",
            "..oppppppppppppppppplnoh",
            "..oppppppppppplppppplloo",
            "...oppppppppppllppppoooh",
            "....olllllllllllpooo...o",
            ".....oddppooddppo.......",
            ".....olllloollllo.......",
            "......oooo..oooo........"
        ],
[
            "........................",
            ".o.............o...o....",
            "opo...........opo.opo...",
            "opo...........onpopno...",
            "opo..oooooooooooppppo...",
            "opooopdppdppdppppppwpo..",
            ".opppppppppppppppppeppoo",
            "..oppppppppppppppppplnoh",
            "..oppppppppppplppppplloo",
            "...oppppppppppllppppoooh",
            "...odlllllllllllpooo...o",
            "...oddppooooooddppo.....",
            "..ollollo.....olllo.....",
            "...oo.oo.......ooo......"
        ]
    ]

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const tot = f.reduce((a, b) => a + b, 0)
            const idle = f[3] + (f[4] || 0)
            if (win._tot > 0 && tot > win._tot) {
                const u = 1 - (idle - win._idle) / (tot - win._tot)
                win.cpu = win.cpu * 0.5 + Math.max(0, Math.min(1, u)) * 0.5
                if (win.cpu > 0.12 && !Settings.reduceMotion) win.catAwake = true
                else if (win.cpu < 0.06 || Settings.reduceMotion) win.catAwake = false
            }
            win._tot = tot
            win._idle = idle
        }
    }
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: stat.reload() }
    Timer {
        interval: 900
        repeat: true
        running: !win.catAwake && !Settings.reduceMotion
        onTriggered: win.sleepFrame = (win.sleepFrame + 1) % 2
    }
    Timer {
        interval: win.catInterval
        repeat: true
        running: win.catAwake
        onTriggered: win.catFrame = (win.catFrame + 1) % win.catRun.length
    }

    // ---- workspace discs: bright + halo = chosen, star = other workspace with windows, cracked = empty ----
    readonly property var discPlain: [
            "...............",
            "....oooo.......",
            "..oo2222oo.....",
            ".o12222333o....",
            ".o22211333o....",
            "o2221..1334o...",
            "o221....144o...",
            "o221....144o...",
            "o2331..1444o...",
            ".o33311444o....",
            ".o33344445o....",
            "..oo4444oo.....",
            "....oooo......."
        ]
    readonly property var discStar: [
            "............y..",
            "....oooo...yYy.",
            "..oo2222..yYYYy",
            ".o12222....yYy.",
            ".o22211.....y..",
            "o2221..1..4o...",
            "o221....144o...",
            "o221....144o...",
            "o2331..1444o...",
            ".o33311444o....",
            ".o33344445o....",
            "..oo4444oo.....",
            "....oooo......."
        ]
    readonly property var discBroken: [
            "...............",
            "....oooo.......",
            "..oo3333oc.....",
            ".o233334c4o....",
            ".o33333cc4o....",
            "o3333..c445o...",
            "o333....355o...",
            "o333....355o...",
            "o34.c..3555o...",
            ".o...33555o....",
            "....455555o....",
            "...o5555oo.....",
            "....oooo......."
        ]
    readonly property var discHalo: [
            "......#.#.......",
            ".....#.#.#.#....",
            "....#.......#...",
            ".............#..",
            "..#...........#.",
            ".#..............",
            "#.............#.",
            ".#.............#",
            "#.............#.",
            ".#.............#",
            "..............#.",
            ".#...........#..",
            "..#.............",
            "...#.......#....",
            "....#.#.#.#.....",
            ".......#.#......"
        ]
    readonly property var discPalette: ({
        "o": "#3a3a40", "1": "#f2f2f4", "2": "#cfcfd4", "3": "#a4a4ac", "4": "#7a7a84", "5": "#55555e",
        "y": "#ffd23f", "Y": "#fff3b0", "c": "#18181c"
    })
    readonly property var discBright: ({
        "o": Theme.accent, "1": "#ffffff", "2": "#f0f0f4", "3": "#d8d8de", "4": "#b8b8c0", "5": "#98989f"
    })
    readonly property int curWs: {
        const m = Hyprland.monitorFor(win.screen)
        if (m && m.activeWorkspace) return m.activeWorkspace.id
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    }
    readonly property var wsIds: {
        const ids = [1, 2, 3, 4, 5]
        const tls = Hyprland.toplevels.values
        for (let i = 0; i < tls.length; i++) {
            const w = tls[i].workspace
            if (w && w.id > 5 && ids.indexOf(w.id) < 0) ids.push(w.id)
        }
        if (curWs > 5 && ids.indexOf(curWs) < 0) ids.push(curWs)
        ids.sort((a, b) => a - b)
        return ids
    }
    function wsCount(id) {
        const tls = Hyprland.toplevels.values
        let n = 0
        for (let i = 0; i < tls.length; i++) {
            const w = tls[i].workspace
            if (w && w.id === id) n++
        }
        return n
    }
    function gotoWs(target) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + target + " })"])
    }

    function layoutCode(name) {
        const n = name.toLowerCase()
        if (n.startsWith("english")) return "EN"
        if (n.startsWith("russian")) return "RU"
        if (n.startsWith("ukrainian")) return "UA"
        return name.substring(0, 2).toUpperCase()
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    SystemClock { id: clk; precision: SystemClock.Minutes }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                win.layout = win.layoutCode(event.data.substring(event.data.indexOf(",") + 1))
        }
    }

    // initial layout (rawEvent only fires on change)
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text).keyboards
                    const m = k.find(d => d.main) ?? k[0]
                    if (m) win.layout = win.layoutCode(m.active_keymap)
                } catch (e) {}
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        Rectangle { width: parent.width; height: 1; color: Theme.line }

        // pixel dither strip under the top edge
        Canvas {
            y: 3
            width: parent.width
            height: 2
            onWidthChanged: requestPaint()
            onPaint: {
                const c = getContext("2d")
                c.clearRect(0, 0, width, height)
                c.fillStyle = "#26ffffff"
                for (let x = 0; x < width; x += 6) c.fillRect(x, 0, 2, 2)
            }
        }
    }

    // ---- start ----
    Item {
        id: start
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        width: 108
        height: 34

        Rectangle { x: 2; y: 2; width: parent.width; height: parent.height; color: "#66000000" }   // hard pixel shadow
        Bevel {
            width: parent.width
            height: parent.height
            down: Store.startOpen || Store.launcherOpen
            fill: (Store.startOpen || Store.launcherOpen) ? "#26ffffff" : sa.containsMouse ? "#14ffffff" : Theme.bg
            edge: Theme.accent
        }
        // pixel star: four tapered points, white (top) to grey (bottom), with a twinkle
        Item {
            id: starBox
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 30

            Pix {
                id: starPix
                rows: [
                    "......2......",
                    "......2......",
                    ".....112....2",
                    ".....112..112",
                    "....11111112.",
                    "....1111112..",
                    "...1222223...",
                    "...1222223...",
                    "..12222223...",
                    ".24444334....",
                    "34....234....",
                    "......334....",
                    ".......44....",
                    "........4....",
                    "........4...."
                ]
                palette: ({ "1": "#ffffff", "2": "#dedee4", "3": "#a8a8b2", "4": "#707080" })
                opacity: sa.containsMouse ? 1 : 0.92
            }
            Pix {
                id: twinkle
                x: 21
                y: 1
                px: 1
                rows: [".#.", "###", ".#."]
                tone: "#ffffff"
                opacity: 0

                SequentialAnimation {
                    running: !Settings.reduceMotion
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1800 }
                    NumberAnimation { target: twinkle; property: "opacity"; from: 0; to: 1; duration: 200 }
                    PauseAnimation { duration: 160 }
                    NumberAnimation { target: twinkle; property: "opacity"; to: 0; duration: 320 }
                }
            }
        }
        Mono {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            text: "START"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            font.weight: Font.Bold
        }
        MouseArea {
            id: sa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (Store.launcherOpen) Store.launcherOpen = false
                else Store.startOpen = !Store.startOpen
            }
        }
    }

    // ---- pixel grip ----
    Column {
        id: sep
        anchors { left: start.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 2
        Repeater {
            model: 5
            Rectangle { width: 2; height: 2; color: Theme.dim }
        }
    }

    // ---- workspace discs ----
    Row {
        id: discs
        anchors { left: sep.right; leftMargin: 10; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        spacing: 2

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => win.gotoWs(event.angleDelta.y > 0 ? '"e-1"' : '"e+1"')
        }

        Repeater {
            model: win.wsIds
            delegate: Item {
                id: dsc
                required property int modelData
                readonly property bool cur: win.curWs === modelData
                readonly property int n: win.wsCount(modelData)
                width: 38
                height: 38

                Rectangle { anchors.fill: parent; color: da.containsMouse ? "#14ffffff" : "transparent" }

                // halo around the chosen disc
                Pix {
                    id: halo
                    visible: dsc.cur
                    x: 0
                    y: 4
                    rows: win.discHalo
                    tone: Theme.accent
                    opacity: 0.55

                    SequentialAnimation {
                        running: dsc.cur && !Settings.reduceMotion
                        loops: Animation.Infinite
                        NumberAnimation { target: halo; property: "opacity"; from: 0.25; to: 0.9; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { target: halo; property: "opacity"; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                Pix {
                    x: 4
                    y: 6
                    rows: dsc.cur ? win.discPlain : (dsc.n > 0 ? win.discStar : win.discBroken)
                    palette: dsc.cur ? win.discBright : win.discPalette
                }

                // shine on the chosen disc
                Repeater {
                    model: (dsc.cur && !Settings.reduceMotion) ? 2 : 0
                    Pix {
                        id: gl
                        required property int index
                        x: index === 0 ? 9 : 22
                        y: index === 0 ? 11 : 26
                        px: 1
                        rows: [".#.", "###", ".#."]
                        tone: "#ffffff"
                        opacity: 0

                        SequentialAnimation {
                            running: true
                            PauseAnimation { duration: gl.index * 700 }
                            SequentialAnimation {
                                loops: Animation.Infinite
                                NumberAnimation { target: gl; property: "opacity"; from: 0; to: 1; duration: 220 }
                                PauseAnimation { duration: 140 }
                                NumberAnimation { target: gl; property: "opacity"; to: 0; duration: 320 }
                                PauseAnimation { duration: 1100 }
                            }
                        }
                    }
                }

                MouseArea {
                    id: da
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: win.gotoWs(dsc.modelData)
                }
            }
        }
    }

    Column {
        id: sep2
        anchors { left: discs.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 2
        Repeater {
            model: 5
            Rectangle { width: 2; height: 2; color: Theme.dim }
        }
    }

    // ---- tray + status + clock (sunken) ----
    Item {
        id: tray
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        height: 38
        width: trayRow.width + 20

        Bevel {
            anchors.fill: parent
            down: true
            fill: "#33000000"
        }

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: SystemTray.items
                delegate: IconImage {
                    id: ti
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 16
                    source: modelData.icon

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) ti.modelData.activate()
                            else if (mouse.button === Qt.MiddleButton) ti.modelData.secondaryActivate()
                            else if (ti.modelData.hasMenu) {
                                const p = ti.mapToItem(null, 0, 0)
                                ti.modelData.display(win, p.x, p.y)
                            }
                        }
                    }
                }
            }

            // cpu cat
            Item {
                visible: Settings.cat
                anchors.verticalCenter: parent.verticalCenter
                width: cp.width
                height: cp.height

                Pix {
                    id: cp
                    palette: win.catPalette
                    rows: win.catAwake ? win.catRun[win.catFrame] : win.catSleep[win.sleepFrame]
                }

                // sleeping "z"
                Pix {
                    id: zz
                    x: 34
                    rows: ["###", ".#.", "###"]
                    tone: "#f5f5f5"
                    opacity: 0
                    visible: !win.catAwake && !Settings.reduceMotion

                    SequentialAnimation {
                        running: !win.catAwake && !Settings.reduceMotion
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: zz; property: "y"; from: 0; to: -9; duration: 2400 }
                            SequentialAnimation {
                                NumberAnimation { target: zz; property: "opacity"; from: 0; to: 0.9; duration: 600 }
                                NumberAnimation { target: zz; property: "opacity"; to: 0; duration: 1800 }
                            }
                        }
                    }
                }
            }

            // keyboard layout: click = next
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: lt.implicitWidth + 14
                height: 24
                Bevel {
                    anchors.fill: parent
                    down: ka.pressed
                    fill: ka.containsMouse ? "#14ffffff" : "transparent"
                }
                Mono {
                    id: lt
                    anchors.centerIn: parent
                    text: win.layout
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                MouseArea {
                    id: ka
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                }
            }

            // volume: click = mute, wheel = +/-5%
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: vr.width + 14
                height: 24
                Bevel {
                    anchors.fill: parent
                    down: va.pressed
                    fill: va.containsMouse ? "#14ffffff" : "transparent"
                    edge: win.muted ? Theme.accentDim : Theme.line
                }
                Row {
                    id: vr
                    anchors.centerIn: parent
                    spacing: 6
                    Pix {
                        anchors.verticalCenter: parent.verticalCenter
                        rows: win.muted ? win.bmMute : win.bmSpeaker
                        tone: win.muted ? Theme.accent : Theme.text
                    }
                    Mono {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(win.vol * 100) + "%"
                        color: win.muted ? Theme.dim : Theme.text
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    id: va
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (win.audio) win.audio.muted = !win.audio.muted
                    onWheel: wheel => {
                        if (!win.audio) return
                        const d = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                        win.audio.volume = Math.max(0, Math.min(1, win.audio.volume + d))
                    }
                }
            }

            // battery test tube: liquid fills bottom-up, bolt when charging,
            // grey steam when discharging, twinkling sparks around the glass
            Row {
                visible: win.hasBat
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: bp.width
                    height: bp.height

                    Pix {
                        id: bp
                        rows: win.batRows(win.batPct, win.charging)
                        palette: win.tubePalette
                        tone2: "#ffffff"
                    }

                    // steam (discharging)
                    Repeater {
                        model: 3
                        Rectangle {
                            id: puff
                            required property int index
                            visible: win.discharging && !Settings.reduceMotion
                            x: 5 + index * 3
                            y: -3
                            width: 2
                            height: 2
                            color: "#c8c8c8"
                            opacity: 0

                            SequentialAnimation {
                                running: win.discharging && !Settings.reduceMotion
                                PauseAnimation { duration: puff.index * 600 }
                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    ParallelAnimation {
                                        NumberAnimation { target: puff; property: "y"; from: -3; to: -10; duration: 1800 }
                                        SequentialAnimation {
                                            NumberAnimation { target: puff; property: "opacity"; from: 0; to: 0.9; duration: 400 }
                                            NumberAnimation { target: puff; property: "opacity"; to: 0; duration: 1400 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // sparks (more of them while charging)
                    Repeater {
                        model: Settings.reduceMotion ? 0 : (win.charging ? 6 : 3)
                        Pix {
                            id: sp
                            required property int index
                            readonly property var spots: [[-6, 6], [20, 3], [-5, 19], [21, 15], [-4, -2], [20, 27]]
                            x: spots[index][0]
                            y: spots[index][1]
                            px: 1
                            rows: [".#.", "###", ".#."]
                            tone: index % 2 === 0 ? "#ffffff" : "#ffe08a"
                            opacity: 0

                            SequentialAnimation {
                                running: true
                                PauseAnimation { duration: 300 + sp.index * 410 }
                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    NumberAnimation { target: sp; property: "opacity"; from: 0; to: 1; duration: 250 }
                                    PauseAnimation { duration: 120 }
                                    NumberAnimation { target: sp; property: "opacity"; to: 0; duration: 350 }
                                    PauseAnimation { duration: 1400 + (sp.index % 3) * 300 }
                                }
                            }
                        }
                    }
                }
                Mono {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.batPct + "%"
                    color: win.discharging && win.batPct <= 20 ? Theme.accent : Theme.text
                    font.pixelSize: 11
                }
            }

            // notifications: orange when any, click = history, middle click = do not disturb
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: bl.width + 8
                height: 22
                Row {
                    id: bl
                    anchors.centerIn: parent
                    spacing: 4
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: bellPix.width
                        height: bellPix.height
                        Pix {
                            id: bellPix
                            rows: win.bmBell
                            tone: Notifs.dnd ? Theme.dim : (Notifs.count > 0 ? Theme.accent : Theme.dim)
                        }
                        // DND slash
                        Rectangle {
                            visible: Notifs.dnd
                            anchors.centerIn: parent
                            width: 22
                            height: 2
                            rotation: -45
                            color: Theme.accent
                        }
                    }
                    Mono {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Notifs.count > 0 && !Notifs.dnd
                        text: Notifs.count
                        color: Theme.accent
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) Notifs.dnd = !Notifs.dnd
                        else Store.notifCenter = !Store.notifCenter
                    }
                }
            }

            // two-line clock
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    Mono { text: Qt.formatDateTime(clk.date, Settings.clock24 ? "HH" : "h"); font.pixelSize: 12 }
                    Mono { text: ":"; color: Theme.accent; font.pixelSize: 12 }
                    Mono { text: Qt.formatDateTime(clk.date, "mm"); font.pixelSize: 12 }
                }
                Mono {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clk.date, "ddd, MMM d")
                    color: Theme.dim
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }
            }
        }
    }

    // ---- task buttons ----
    Item {
        id: tasks
        anchors {
            left: sep2.right; leftMargin: 10
            right: tray.left; rightMargin: 8
            top: parent.top; bottom: parent.bottom
        }
        readonly property int n: ToplevelManager.toplevels.values.length

        Row {
            anchors { verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
            spacing: 4

            Repeater {
                model: ToplevelManager.toplevels
                delegate: Item {
                    id: tb
                    required property var modelData
                    width: Math.max(60, Math.min(170, Math.floor((tasks.width - 4 * (tasks.n - 1)) / Math.max(1, tasks.n))))
                    height: 34

                    Bevel {
                        anchors.fill: parent
                        down: tb.modelData.activated
                        fill: tb.modelData.activated ? "#26ffffff" : ta.containsMouse ? "#14ffffff" : "transparent"
                        edge: tb.modelData.activated ? Theme.accent : Theme.line
                    }
                    IconImage {
                        id: ic
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: Quickshell.iconPath(tb.modelData.appId, "application-x-executable")
                    }
                    Mono {
                        anchors {
                            left: ic.right; leftMargin: 8
                            right: parent.right; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: (tb.modelData.title !== "" ? tb.modelData.title : tb.modelData.appId).toUpperCase()
                        color: tb.modelData.activated ? Theme.text : Theme.dim
                        font.pixelSize: 11
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: ta
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) tb.modelData.close()
                            else tb.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
