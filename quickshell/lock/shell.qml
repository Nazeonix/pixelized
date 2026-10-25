import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Lock screen: black, stacked title, big clock, password, and a tile network whose
// orange paths connect step by step. Run with:  qs -c lock   (~/.config/quickshell/lock/shell.qml)
ShellRoot {
    id: root

    // ---- tweak here ----
    readonly property string title: "LINK"          // stacked letters on the left
    readonly property string pamService: "login"    // /etc/pam.d/<name>
    readonly property color orange: "#ff7a18"
    readonly property color paper: "#ecece8"
    readonly property color ink: "#070707"

    // ---- state ----
    property string pw: ""
    property string pending: ""
    property string status: ""          // "", VERIFYING, ACCESS DENIED
    property bool busy: false
    property string host: ""

    function submit() {
        if (busy || pw.length === 0) return
        pending = pw
        busy = true
        status = "VERIFYING"
        pam.start()
    }
    function fail() {
        busy = false
        pw = ""
        status = "ACCESS DENIED"
        clearStatus.restart()
    }
    Timer { id: clearStatus; interval: 1800; onTriggered: if (!root.busy) root.status = "" }

    PamContext {
        id: pam
        config: root.pamService
        onPamMessage: {
            if (responseRequired) respond(root.pending)
        }
        onCompleted: result => {
            root.pending = ""
            if (result === PamResult.Success) lock.locked = false
            else root.fail()
        }
        onError: root.fail()
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim().toUpperCase()
    }

    // ---- tile network: plus-shaped tiles; boundary lines form the graph ----
    readonly property int cells: 25                 // cells per side
    property var edges: []                      // [x1, y1, x2, y2] lattice units
    property var dots: []
    property var adj: ({})
    property var walkers: []
    property int tick: 0
    property bool built: false
    readonly property int trailLen: 46
    signal stepped()

    function mod5(a) { return ((a % 5) + 5) % 5 }

    function tileKey(x, y) {
        const c = [[0, 0], [-1, 0], [1, 0], [0, -1], [0, 1]]
        for (let k = 0; k < 5; k++) {
            const cx = x + c[k][0], cy = y + c[k][1]
            if (mod5(cx + 2 * cy) === 0) return cx + "," + cy
        }
        return ""
    }

    function build() {
        const n = cells, W = n + 1
        const E = [], A = {}, D = []
        const add = (x1, y1, x2, y2) => {
            const i = E.length
            E.push([x1, y1, x2, y2])
            const a = y1 * W + x1, b = y2 * W + x2
            ;(A[a] = A[a] || []).push(i)
            ;(A[b] = A[b] || []).push(i)
        }
        for (let j = 0; j <= n; j++)
            for (let i = 0; i < n; i++)
                if (tileKey(i, j - 1) !== tileKey(i, j)) add(i, j, i + 1, j)
        for (let j = 0; j < n; j++)
            for (let i = 0; i <= n; i++)
                if (tileKey(i - 1, j) !== tileKey(i, j)) add(i, j, i, j + 1)
        for (let y = 0; y < n; y++)
            for (let x = 0; x < n; x++)
                if (mod5(x + 2 * y) === 0) D.push([x + 0.5, y + 0.5])
        edges = E
        adj = A
        dots = D
        const w = []
        for (let k = 0; k < 5; k++) w.push({ node: randomNode(), last: -1, trail: [] })
        walkers = w
        built = true
    }

    function randomNode() {
        const keys = Object.keys(adj)
        return Number(keys[Math.floor(Math.random() * keys.length)])
    }

    function stepWalkers() {
        tick++
        const W = cells + 1
        for (const w of walkers) {
            const recent = w.trail.slice(-12).map(t => t.e)
            let opts = (adj[w.node] || []).filter(e => e !== w.last && recent.indexOf(e) < 0)
            if (opts.length === 0 || Math.random() < 0.015) {
                w.node = randomNode()
                w.last = -1
                continue
            }
            const e = opts[Math.floor(Math.random() * opts.length)]
            const ed = edges[e]
            const a = ed[1] * W + ed[0]
            w.node = (a === w.node) ? ed[3] * W + ed[2] : a
            w.last = e
            w.trail.push({ e: e, t: tick })
            if (w.trail.length > trailLen) w.trail.shift()
        }
        stepped()
    }

    Component.onCompleted: build()
    Timer { interval: 85; repeat: true; running: root.built; onTriggered: root.stepWalkers() }

    // ---- the lock ----
    WlSessionLock {
        id: lock
        locked: true
        onLockedChanged: if (!locked) Qt.quit()

        WlSessionLockSurface {
            id: surf
            color: root.ink

            Item {
                id: scene
                anchors.fill: parent
                focus: true

                // layout is designed on a 965x648 sheet and scaled to fit
                readonly property real u: Math.min(width / 965, height / 648)
                readonly property real ox: (width - 965 * u) / 2
                readonly property real oy: (height - 648 * u) / 2
                function sx(v) { return ox + v * u }
                function sy(v) { return oy + v * u }

                SystemClock { id: clk; precision: SystemClock.Minutes }
                readonly property var en: Qt.locale("en_US")

                Keys.onPressed: event => {
                    if (root.busy) return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.submit()
                    else if (event.key === Qt.Key_Backspace) root.pw = root.pw.slice(0, -1)
                    else if (event.key === Qt.Key_Escape || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U)) root.pw = ""
                    else if (event.text.length === 1 && event.text >= " " && event.key !== Qt.Key_Delete) root.pw += event.text
                    else return
                    if (root.status === "ACCESS DENIED") root.status = ""
                    event.accepted = true
                }

                // ---- left: line + stacked title ----
                Rectangle { x: scene.sx(29); y: scene.sy(71); width: Math.max(2, 3 * scene.u); height: 492 * scene.u; color: root.orange }

                Column {
                    x: scene.sx(40)
                    y: scene.sy(66)
                    width: 100 * scene.u
                    Repeater {
                        model: root.title.split("")
                        Text {
                            required property string modelData
                            width: 100 * scene.u
                            height: 105 * scene.u
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: root.paper
                            font.family: "Liberation Sans"
                            font.weight: Font.Light
                            font.pixelSize: 96 * scene.u
                        }
                    }
                }
                Text {
                    x: scene.sx(44); y: scene.sy(514)
                    text: root.host !== "" ? root.host : "LOCKED"
                    color: root.paper
                    font.family: "JetBrains Mono"
                    font.pixelSize: 15 * scene.u
                    font.letterSpacing: 3 * scene.u
                }
                Text {
                    x: scene.sx(44); y: scene.sy(549)
                    text: "CLOVER / LOCK"
                    color: "#7a7a76"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10 * scene.u
                    font.letterSpacing: 2 * scene.u
                }

                // ---- middle: status, clock, date, user, password ----
                Text {
                    x: scene.sx(165); y: scene.sy(172)
                    text: "SESSION LOCKED"
                    color: "#8a8a86"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10 * scene.u
                    font.letterSpacing: 3 * scene.u
                }
                Row {
                    x: scene.sx(162); y: scene.sy(186)
                    Text { text: Qt.formatDateTime(clk.date, "HH"); color: root.paper; font.family: "Liberation Sans"; font.pixelSize: 74 * scene.u }
                    Text { text: ":"; color: root.orange; font.family: "Liberation Sans"; font.pixelSize: 74 * scene.u }
                    Text { text: Qt.formatDateTime(clk.date, "mm"); color: root.paper; font.family: "Liberation Sans"; font.pixelSize: 74 * scene.u }
                }
                Row {
                    x: scene.sx(165); y: scene.sy(273)
                    spacing: 6 * scene.u
                    Text { text: scene.en.toString(clk.date, "ddd").toUpperCase(); color: "#8a8a86"; font.family: "JetBrains Mono"; font.pixelSize: 10 * scene.u; font.letterSpacing: 2 * scene.u }
                    Text { text: "//"; color: root.orange; font.family: "JetBrains Mono"; font.pixelSize: 10 * scene.u }
                    Text { text: scene.en.toString(clk.date, "d MMMM yyyy").toUpperCase(); color: "#8a8a86"; font.family: "JetBrains Mono"; font.pixelSize: 10 * scene.u; font.letterSpacing: 2 * scene.u }
                }

                Row {
                    x: scene.sx(165); y: scene.sy(331)
                    spacing: 6 * scene.u
                    Text { text: "USER"; color: "#8a8a86"; font.family: "JetBrains Mono"; font.pixelSize: 10 * scene.u; font.letterSpacing: 2 * scene.u }
                    Text { text: "//"; color: root.orange; font.family: "JetBrains Mono"; font.pixelSize: 10 * scene.u }
                    Text { text: "01"; color: "#8a8a86"; font.family: "JetBrains Mono"; font.pixelSize: 10 * scene.u; font.letterSpacing: 2 * scene.u }
                }
                Text {
                    x: scene.sx(165); y: scene.sy(355)
                    text: Quickshell.env("USER")
                    color: root.paper
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13 * scene.u
                }

                Text {
                    x: scene.sx(165); y: scene.sy(399)
                    text: root.status !== "" ? root.status : "PASSWORD"
                    color: root.status === "ACCESS DENIED" ? root.orange : "#8a8a86"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10 * scene.u
                    font.letterSpacing: 3 * scene.u
                }
                // input
                Item {
                    x: scene.sx(165); y: scene.sy(424)
                    width: 294 * scene.u
                    height: 44 * scene.u

                    Text {
                        visible: root.pw.length === 0
                        x: 4 * scene.u
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type password…"
                        color: "#8a8a86"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12 * scene.u
                    }
                    Row {
                        x: 4 * scene.u
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5 * scene.u
                        Repeater {
                            model: Math.min(root.pw.length, 30)
                            Rectangle { width: 7 * scene.u; height: 7 * scene.u; color: root.busy ? "#7a7a76" : root.paper }
                        }
                        Rectangle {
                            width: 2 * scene.u
                            height: 16 * scene.u
                            color: root.orange
                            visible: !root.busy
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: Math.max(1, scene.u)
                        color: root.status === "ACCESS DENIED" ? root.orange : "#8a8a86"
                    }
                }
                // confirm button
                Text {
                    x: scene.sx(515) - width; y: scene.sy(399)
                    text: "CONFIRM"
                    color: "#8a8a86"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10 * scene.u
                    font.letterSpacing: 2 * scene.u
                }
                Rectangle {
                    x: scene.sx(471); y: scene.sy(424)
                    width: 44 * scene.u
                    height: 44 * scene.u
                    color: root.busy ? "#8a3d0a" : (bm.containsMouse ? "#ff9a4a" : root.orange)

                    Text {
                        anchors.centerIn: parent
                        text: ">"
                        color: root.ink
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: 20 * scene.u
                    }
                    MouseArea {
                        id: bm
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { scene.forceActiveFocus(); root.submit() }
                    }
                }

                // ---- right: tile network ----
                Canvas {
                    id: base
                    x: scene.sx(563); y: scene.sy(123)
                    width: 350 * scene.u
                    height: 350 * scene.u
                    onWidthChanged: requestPaint()
                    Connections { target: root; function onBuiltChanged() { base.requestPaint() } }
                    onPaint: {
                        const c = getContext("2d")
                        c.clearRect(0, 0, width, height)
                        if (!root.built) return
                        const s = width / root.cells
                        c.lineWidth = Math.max(1, scene.u)
                        c.strokeStyle = "#5c5c58"
                        c.beginPath()
                        for (const e of root.edges) { c.moveTo(e[0] * s, e[1] * s); c.lineTo(e[2] * s, e[3] * s) }
                        c.stroke()
                        c.fillStyle = "#2a2a28"
                        const d = Math.max(2, 2 * scene.u)
                        for (const p of root.dots) c.fillRect(p[0] * s - d / 2, p[1] * s - d / 2, d, d)
                    }
                }
                Canvas {
                    id: live
                    x: base.x; y: base.y
                    width: base.width
                    height: base.height
                    Connections { target: root; function onStepped() { live.requestPaint() } }
                    onPaint: {
                        const c = getContext("2d")
                        c.clearRect(0, 0, width, height)
                        if (!root.built) return
                        const s = width / root.cells, W = root.cells + 1
                        c.lineWidth = Math.max(2, 2 * scene.u)
                        c.lineCap = "square"
                        for (const w of root.walkers) {
                            for (const t of w.trail) {
                                const a = 1 - (root.tick - t.t) / root.trailLen
                                if (a <= 0) continue
                                const e = root.edges[t.e]
                                c.strokeStyle = "rgba(255,122,24," + a.toFixed(2) + ")"
                                c.beginPath()
                                c.moveTo(e[0] * s, e[1] * s)
                                c.lineTo(e[2] * s, e[3] * s)
                                c.stroke()
                            }
                            // head
                            const hx = (w.node % W) * s, hy = Math.floor(w.node / W) * s
                            const h = Math.max(4, 4 * scene.u)
                            c.fillStyle = "#ffffff"
                            c.fillRect(hx - h / 2, hy - h / 2, h, h)
                        }
                    }
                }

                Rectangle { x: scene.sx(549); y: scene.sy(500); width: 380 * scene.u; height: Math.max(1, scene.u); color: "#44443f" }
                Text {
                    x: scene.sx(549); y: scene.sy(515)
                    text: "A"
                    color: root.orange
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10 * scene.u
                }
                Text {
                    x: scene.sx(929) - width; y: scene.sy(515)
                    text: "RELAY TILES"
                    color: "#8a8a86"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10 * scene.u
                    font.letterSpacing: 2 * scene.u
                }
            }
        }
    }
}
