import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire

// Clover settings. Open: START menu -> Settings, or  qs -c clover ipc call clover settings
FloatingWindow {
    id: win

    title: "Clover · Settings"
    visible: Store.settingsOpen
    onVisibleChanged: {
        if (!visible) Store.settingsOpen = false
        else refresh()
    }
    implicitWidth: 1040
    implicitHeight: 700
    color: "transparent"

    property string page: "home"
    readonly property bool searching: Store.settingsQuery !== ""

    readonly property var pages: [
        { id: "home",          label: "Home",           icon: "heart" },
        { id: "presets",       label: "Presets",        icon: "sparkle" },
        { id: "system",        label: "System",         icon: "chip" },
        { id: "devices",       label: "Devices",        icon: "mouse" },
        { id: "power",         label: "Power & idle",   icon: "power" },
        { id: "network",       label: "Network",        icon: "wifi" },
        { id: "personal",      label: "Personalization", icon: "brush" },
        { id: "desktop",       label: "Desktop",        icon: "grid" },
        { id: "windows",       label: "Windows",        icon: "window" },
        { id: "apps",          label: "Apps",           icon: "apps" },
        { id: "notifications", label: "Notifications",  icon: "bell" },
        { id: "access",        label: "Accessibility",  icon: "person" },
        { id: "updates",       label: "Updates",        icon: "download" },
        { id: "about",         label: "About",          icon: "info" }
    ]
    readonly property string pageLabel: {
        for (let i = 0; i < pages.length; i++) if (pages[i].id === page) return pages[i].label
        return ""
    }

    // ---------------- data ----------------
    property var info: ({})
    property real brightness: 0.5
    property string layoutName: ""
    property bool wifiOn: false
    property string wifiActive: ""
    property var wifiList: []
    property bool btOn: false
    property var btDevices: []
    property bool updChecked: false
    property bool updBusy: false
    property var updRepo: []
    property var updAur: []
    property string lastUpgrade: ""
    property string qsVersion: ""
    property int gapsIn: 4
    property int gapsOut: 8
    property int rounding: 16
    property bool winAnim: true
    property string armed: ""

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    onPageChanged: refresh()

    function kv(t) {
        const o = {}
        t.split("\n").forEach(l => {
            const i = l.indexOf("=")
            if (i > 0) o[l.substring(0, i)] = l.substring(i + 1).trim()
        })
        return o
    }

    function refresh() {
        if (!visible) return
        if (page === "system") sysInfo.run()
        else if (page === "devices") { bri.run(); kb.run() }
        else if (page === "network") { wifi.run(); wact.run(); scan.run(); bt.run(); btd.run() }
        else if (page === "updates" && !updChecked) checkUpdates()
        else if (page === "about") qsv.run()
    }

    function checkUpdates() {
        updBusy = true
        updChecked = true
        repo.run()
        aur.run()
        lastup.run()
    }

    function inTerminal(script) {
        const t = Settings.termCmd.trim().split(/\s+/)
        Quickshell.execDetached(t.concat(["-e", "sh", "-c", script + "; echo; read -p 'Done. Press Enter to close ' _"]))
    }

    function confirm(id, fn) {
        if (armed !== id) { armed = id; armTimer.restart(); return }
        armed = ""
        fn()
    }
    Timer { id: armTimer; interval: 3000; onTriggered: win.armed = "" }

    function fmt(sec) {
        if (sec <= 0) return "Off"
        if (sec < 60) return sec + " s"
        const m = sec / 60
        if (m < 60) return (m % 1 === 0 ? m : m.toFixed(1)) + " min"
        const h = m / 60
        return (h % 1 === 0 ? h : h.toFixed(1)) + " h"
    }
    function idle(fn) { Quickshell.execDetached(["qs", "-c", "clover", "ipc", "call", "idle", fn]) }

    function hypr(key, value) { Quickshell.execDetached(["hyprctl", "keyword", key, String(value)]) }

    // ---------------- helpers (shell commands) ----------------
    component Sh: Item {
        id: sh
        property var command: []
        signal done(string text)
        function run() { p.running = false; p.running = true }
        Process {
            id: p
            command: sh.command
            stdout: StdioCollector { onStreamFinished: sh.done(text) }
        }
    }

    Sh {
        id: sysInfo
        command: ["sh", "-c", "echo host=$(cat /etc/hostname 2>/dev/null); echo os=$(. /etc/os-release; echo $PRETTY_NAME); echo kernel=$(uname -r); echo cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //'); echo mem=$(free -h | awk '/Mem/{print $3 \" / \" $2}'); echo up=$(uptime -p | sed 's/^up //')"]
        onDone: t => win.info = win.kv(t)
    }
    Sh {
        id: bri
        command: ["brightnessctl", "-m"]
        onDone: t => {
            const p = t.trim().split(",")
            const n = Number((p[3] || "").replace("%", ""))
            if (!isNaN(n) && p.length >= 4) win.brightness = n / 100
        }
    }
    Sh {
        id: kb
        command: ["hyprctl", "devices", "-j"]
        onDone: t => {
            try {
                const k = JSON.parse(t).keyboards
                const m = k.find(d => d.main) ?? k[0]
                if (m) win.layoutName = m.active_keymap
            } catch (e) { }
        }
    }
    Sh {
        id: wifi
        command: ["nmcli", "radio", "wifi"]
        onDone: t => win.wifiOn = t.trim() === "enabled"
    }
    Sh {
        id: wact
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active | grep -v loopback | head -1 | cut -d: -f1"]
        onDone: t => win.wifiActive = t.trim()
    }
    Sh {
        id: scan
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | head -20"]
        onDone: t => {
            const seen = {}
            const out = []
            t.split("\n").forEach(l => {
                const p = l.split(":")
                if (p.length < 4 || p[1] === "" || seen[p[1]]) return
                seen[p[1]] = true
                out.push({ use: p[0] === "*", ssid: p[1], sig: p[2], sec: p[3] })
            })
            win.wifiList = out.slice(0, 10)
        }
    }
    Sh {
        id: bt
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -i 'Powered:' | awk '{print $2}'"]
        onDone: t => win.btOn = t.trim() === "yes"
    }
    Sh {
        id: btd
        command: ["sh", "-c", "bluetoothctl devices Paired 2>/dev/null || bluetoothctl devices 2>/dev/null"]
        onDone: t => {
            const out = []
            t.split("\n").forEach(l => {
                const m = l.match(/^Device\s+(\S+)\s+(.*)$/)
                if (m) out.push({ mac: m[1], name: m[2] })
            })
            win.btDevices = out
        }
    }
    Sh {
        id: repo
        command: ["sh", "-c", "checkupdates 2>/dev/null"]
        onDone: t => { win.updRepo = t.split("\n").filter(l => l.trim() !== ""); win.updBusy = false }
    }
    Sh {
        id: aur
        command: ["sh", "-c", "if command -v paru >/dev/null; then paru -Qua 2>/dev/null; elif command -v yay >/dev/null; then yay -Qua 2>/dev/null; fi"]
        onDone: t => win.updAur = t.split("\n").filter(l => l.trim() !== "")
    }
    Sh {
        id: lastup
        command: ["sh", "-c", "grep -a 'starting full system upgrade' /var/log/pacman.log | tail -1 | cut -c2-17"]
        onDone: t => win.lastUpgrade = t.trim()
    }
    Sh {
        id: qsv
        command: ["qs", "--version"]
        onDone: t => win.qsVersion = t.trim()
    }

    Timer { id: briTimer; interval: 120; property real v: 0.5; onTriggered: Quickshell.execDetached(["brightnessctl", "set", Math.max(1, Math.round(v * 100)) + "%"]) }
    Timer { id: kbTimer; interval: 300; onTriggered: kb.run() }
    Timer { id: netTimer; interval: 1500; onTriggered: { wifi.run(); wact.run(); scan.run() } }
    Timer { id: btTimer; interval: 1200; onTriggered: { bt.run(); btd.run() } }

    // ---------------- UI building blocks ----------------
    component SVal: Mono {
        color: Theme.dim
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
    }

    component SSection: Item {
        id: sec
        property string title: ""
        default property alias content: col.data
        width: parent ? parent.width : 0
        height: visible ? 34 + col.height + 4 : 0
        visible: col.height > 0

        Rectangle { x: 0; y: 11; width: 8; height: 8; color: Theme.accent }
        Mono {
            x: 18
            y: 6
            text: sec.title.toUpperCase()
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 2
        }
        Column {
            id: col
            y: 32
            width: parent.width
            spacing: 2
        }
    }

    component SRow: Item {
        id: row
        property string label: ""
        property string desc: ""
        default property alias control: slot.data
        property bool show: true
        readonly property bool match: show && (Store.settingsQuery === "" || (label + " " + desc).toLowerCase().indexOf(Store.settingsQuery) >= 0)

        width: parent ? parent.width : 0
        height: match ? Math.max(52, txt.height + 22) : 0
        visible: match

        Rectangle { anchors.fill: parent; color: "#14ffffff" }
        Rectangle { x: 0; y: parent.height - 1; width: parent.width; height: 1; color: "#0dffffff" }

        Column {
            id: txt
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, parent.width - slot.width - 56)
            spacing: 3
            Mono {
                width: parent.width
                wrapMode: Text.Wrap
                text: row.label
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            Mono {
                visible: row.desc !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: row.desc
                color: Theme.dim
                font.pixelSize: 9
            }
        }
        Item {
            id: slot
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    component SToggle: Item {
        id: tg
        property bool checked: false
        signal toggled(bool value)
        width: 54
        height: 24

        Bevel {
            anchors.fill: parent
            down: true
            fill: tg.checked ? Theme.accentDim : "#59000000"
            edge: tg.checked ? Theme.accent : Theme.line
        }
        Rectangle {
            x: tg.checked ? parent.width - 22 : 4
            y: 4
            width: 16
            height: 16
            color: tg.checked ? Theme.accent : "#8c8c8c"
            Behavior on x { NumberAnimation { duration: 90 } }
        }
        MouseArea { anchors.fill: parent; onClicked: tg.toggled(!tg.checked) }
    }

    component SChoice: Row {
        id: ch
        property var options: []
        property int current: 0
        signal picked(int index)
        spacing: 4

        Repeater {
            model: ch.options
            delegate: Item {
                id: ci
                required property string modelData
                required property int index
                width: ct.implicitWidth + 20
                height: 26

                Bevel {
                    anchors.fill: parent
                    down: ci.index === ch.current
                    fill: ci.index === ch.current ? Theme.accentDim : (cm.containsMouse ? "#26ffffff" : "transparent")
                    edge: ci.index === ch.current ? Theme.accent : Theme.line
                }
                Mono {
                    id: ct
                    anchors.centerIn: parent
                    text: ci.modelData.toUpperCase()
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; onClicked: ch.picked(ci.index) }
            }
        }
    }

    component SBtn: Item {
        id: bt2
        property string label: ""
        property bool danger: false
        signal clicked()
        width: bl.implicitWidth + 28
        height: 26

        Bevel {
            anchors.fill: parent
            down: bm.pressed
            fill: bm.containsMouse ? (bt2.danger ? Theme.accentDim : "#26ffffff") : "transparent"
            edge: bt2.danger ? Theme.accent : Theme.line
        }
        Mono {
            id: bl
            anchors.centerIn: parent
            text: bt2.label.toUpperCase()
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; onClicked: bt2.clicked() }
    }

    component SSlider: Item {
        id: sl
        property real value: 0          // 0..1
        property real max: 100
        property string suffix: "%"
        property string readout: ""       // overrides the number shown on the right
        signal moved(real v)
        width: 270
        height: 26

        Bevel { x: 0; y: 8; width: 190; height: 10; down: true; fill: "#59000000" }
        Rectangle { x: 2; y: 10; width: Math.max(0, 186 * sl.value); height: 6; color: Theme.accent }
        Rectangle { x: 2 + 186 * sl.value - 4; y: 4; width: 8; height: 18; color: Theme.text }
        Mono {
            x: 202
            anchors.verticalCenter: parent.verticalCenter
            text: sl.readout !== "" ? sl.readout : Math.round(sl.value * sl.max) + sl.suffix
            font.pixelSize: 10
        }
        MouseArea {
            x: 0
            width: 190
            height: parent.height
            onPressed: mouse => sl.moved(Math.max(0, Math.min(1, (mouse.x - 2) / 186)))
            onPositionChanged: mouse => { if (pressed) sl.moved(Math.max(0, Math.min(1, (mouse.x - 2) / 186))) }
        }
    }

    component SText: Item {
        id: st
        property string text: ""
        property string placeholder: ""
        signal edited(string value)
        width: 260
        height: 28

        Bevel {
            anchors.fill: parent
            down: true
            fill: "#59000000"
            edge: ti.activeFocus ? Theme.accent : Theme.line
        }
        TextInput {
            id: ti
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            text: st.text
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 11
            clip: true
            selectByMouse: true
            onEditingFinished: st.edited(text)
        }
        Mono {
            visible: ti.text === ""
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: st.placeholder
            color: Theme.dim
            font.pixelSize: 11
        }
    }

    // ---------------- layout ----------------
    Rectangle { anchors.fill: parent; color: Theme.bg }

    // sidebar
    Item {
        id: side
        x: 0
        y: 0
        width: 270
        height: parent.height

        Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Theme.line }

        // user card
        Item {
            x: 14
            y: 14
            width: 242
            height: 50

            Item {
                visible: Settings.pixelAvatar
                width: 46
                height: 46
                Bevel { anchors.fill: parent; down: true; fill: "#59000000"; edge: Theme.accentDim }
                Pix { anchors.centerIn: parent; px: 3; rows: Icons.bm.heart; palette: Icons.pal.heart }
            }
            Column {
                x: Settings.pixelAvatar ? 56 : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Mono { text: Settings.displayName; font.pixelSize: 12; font.weight: Font.Bold }
                Mono { text: "Account"; color: Theme.dim; font.pixelSize: 9; font.letterSpacing: 1 }
            }
        }

        // search
        Item {
            x: 14
            y: 76
            width: 242
            height: 36

            Bevel { anchors.fill: parent; down: true; fill: "#59000000"; edge: search.activeFocus ? Theme.accent : Theme.line }
            Pix { x: 8; anchors.verticalCenter: parent.verticalCenter; px: 2; rows: Icons.bm.search; palette: Icons.pal.search }
            Mono {
                visible: search.text === ""
                anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
                text: "SEARCH"
                color: Theme.dim
                font.pixelSize: 10
                font.letterSpacing: 2
            }
            TextInput {
                id: search
                anchors { left: parent.left; leftMargin: 40; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 11
                clip: true
                selectByMouse: true
                onTextChanged: Store.settingsQuery = text.trim().toLowerCase()
                Keys.onEscapePressed: text = ""
            }
        }

        // page list
        Column {
            x: 8
            y: 124
            width: 254
            spacing: 2

            Repeater {
                model: win.pages
                delegate: Item {
                    id: pr
                    required property var modelData
                    readonly property bool sel: win.page === modelData.id && !win.searching
                    width: 254
                    height: 34

                    Rectangle { anchors.fill: parent; color: pr.sel ? "#26ffffff" : (pa.containsMouse ? "#14ffffff" : "transparent") }
                    Rectangle { visible: pr.sel; width: 3; height: parent.height; color: Theme.accent }
                    Pix {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        rows: Icons.bm[pr.modelData.icon]
                        tone: pr.sel ? Theme.accent : Theme.text
                        palette: pr.modelData.icon === "heart" ? Icons.pal.heart : ({})
                    }
                    Mono {
                        x: 48
                        anchors.verticalCenter: parent.verticalCenter
                        text: pr.modelData.label
                        color: pr.sel ? Theme.text : Theme.dim
                        font.pixelSize: 11
                        font.weight: pr.sel ? Font.Bold : Font.Normal
                    }
                    MouseArea {
                        id: pa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { search.text = ""; win.page = pr.modelData.id }
                    }
                }
            }
        }
    }

    // header
    Item {
        id: head
        x: side.width
        y: 0
        width: parent.width - side.width
        height: 76

        Mono {
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: win.searching ? "SEARCH" : win.pageLabel.toUpperCase()
            font.pixelSize: 26
            font.weight: Font.Bold
            font.letterSpacing: 4
        }
        Row {
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            spacing: 6
            SBtn { label: "Reload shell"; onClicked: Quickshell.reload(false) }
        }
    }

    // content
    Flickable {
        id: flick
        x: side.width + 16
        y: head.height
        width: parent.width - side.width - 32
        height: parent.height - head.height - 12
        clip: true
        contentWidth: width
        contentHeight: pagesCol.height + 30
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Rectangle {
            visible: flick.contentHeight > flick.height
            x: flick.width - 6
            y: flick.height * flick.visibleArea.yPosition
            width: 4
            height: flick.height * flick.visibleArea.heightRatio
            color: Theme.accentDim
            z: 5
        }

        Column {
            id: pagesCol
            width: flick.width - 14
            spacing: 14

            // ================= HOME =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "home"

                SSection {
                    title: "Account"
                    SRow {
                        label: "Name"
                        desc: "Leave empty to use your system user name."
                        SText { text: Settings.userName; placeholder: Quickshell.env("USER"); onEdited: v => Settings.set("userName", v.trim()) }
                    }
                    SRow {
                        label: "Pixel avatar"
                        desc: "Show the pixel heart avatar in menus."
                        SToggle { checked: Settings.pixelAvatar; onToggled: v => Settings.set("pixelAvatar", v) }
                    }
                }
                SSection {
                    title: "Shortcuts"
                    SRow { label: "Launcher"; desc: "Search and start apps."; SVal { text: "SUPER + SPACE" } }
                    SRow { label: "Alt-Tab"; desc: "Switch windows, release Alt to confirm."; SVal { text: "ALT + TAB" } }
                    SRow { label: "Edit desktop"; desc: "Drag and resize widgets."; SVal { text: "SUPER + A" } }
                    SRow { label: "Hide widgets"; desc: "Focus mode."; SVal { text: "SUPER + H" } }
                    SRow { label: "Notes"; desc: "Show or hide the notes widget."; SVal { text: "SUPER + N" } }
                    SRow { label: "Lock screen"; SVal { text: "SUPER + L" } }
                }
                SSection {
                    title: "Backup"
                    SRow {
                        label: "Settings file"
                        desc: "Copy settings to ~/Documents/clover-settings.json, or restore them from it."
                        Row {
                            spacing: 6
                            SBtn {
                                label: "Save"
                                onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p ~/Documents && cp ~/.config/quickshell/clover/settings.json ~/Documents/clover-settings.json"])
                            }
                            SBtn {
                                label: "Restore"
                                onClicked: { Quickshell.execDetached(["sh", "-c", "cp ~/Documents/clover-settings.json ~/.config/quickshell/clover/settings.json"]); restoreTimer.restart() }
                            }
                        }
                    }
                }
            }

            // ================= PRESETS =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "presets"

                SSection {
                    title: "Color presets"
                    Repeater {
                        model: Settings.presetIds
                        delegate: SRow {
                            required property string modelData
                            label: Settings.presets[modelData].name
                            desc: modelData === "wallpaper" ? "Colors taken from the current wallpaper with matugen." : "Accent " + Settings.presets[modelData].accent
                            Row {
                                spacing: 10
                                Rectangle { width: 26; height: 26; color: Settings.swatch(modelData) }
                                SBtn { label: Settings.preset === modelData ? "Active" : "Apply"; onClicked: Settings.applyBundle(modelData) }
                            }
                        }
                    }
                }
                SSection {
                    title: "Wallpaper colors"
                    SRow {
                        label: "Palette style"
                        desc: "How matugen builds the palette from the picture."
                        SChoice {
                            options: Settings.wpSchemeNames
                            current: Math.max(0, Settings.wpSchemes.indexOf(Settings.wpScheme))
                            onPicked: i => Settings.set("wpScheme", Settings.wpSchemes[i])
                        }
                    }
                    SRow {
                        label: "Status"
                        desc: Settings.preset === "wallpaper" ? "Colors update by themselves when the wallpaper changes." : "Choose the Wallpaper preset above to use these colors."
                        SVal { text: Settings.wpStatus !== "" ? Settings.wpStatus : (Settings.wp.accent !== undefined ? "Cached colors loaded" : "Not extracted yet") }
                    }
                    SRow {
                        label: "Extract now"
                        desc: "Reads the current wallpaper again. Needs matugen (paru -S matugen-bin)."
                        SBtn { label: "Extract"; onClicked: Settings.refreshColors() }
                    }
                }
                SSection {
                    title: "Bundles"
                    SRow {
                        label: "Minimal"
                        desc: "No cat, no titlebars, reduced motion."
                        SBtn { label: "Apply"; onClicked: Settings.applyBundle("minimal") }
                    }
                    SRow {
                        label: "Full"
                        desc: "Cat, titlebars and all effects."
                        SBtn { label: "Apply"; onClicked: Settings.applyBundle("full") }
                    }
                }
            }

            // ================= SYSTEM =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "system"

                SSection {
                    title: "This computer"
                    SRow { label: "Host name"; SVal { text: win.info.host || "…" } }
                    SRow { label: "Operating system"; SVal { text: win.info.os || "…" } }
                    SRow { label: "Kernel"; SVal { text: win.info.kernel || "…" } }
                    SRow { label: "Processor"; SVal { text: win.info.cpu || "…" } }
                    SRow { label: "Memory used"; SVal { text: win.info.mem || "…" } }
                    SRow { label: "Uptime"; SVal { text: win.info.up || "…" } }
                    SRow { label: "Refresh"; desc: "Read the values again."; SBtn { label: "Refresh"; onClicked: sysInfo.run() } }
                }
                SSection {
                    title: "Power"
                    SRow {
                        label: "Lock"
                        SBtn { label: "Lock now"; onClicked: Quickshell.execDetached(["qs", "-c", "lock"]) }
                    }
                    SRow {
                        label: "Log out"
                        SBtn { label: win.armed === "logout" ? "Click again" : "Log out"; danger: true; onClicked: win.confirm("logout", () => Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"])) }
                    }
                    SRow {
                        label: "Restart"
                        SBtn { label: win.armed === "reboot" ? "Click again" : "Restart"; danger: true; onClicked: win.confirm("reboot", () => Quickshell.execDetached(["systemctl", "reboot"])) }
                    }
                    SRow {
                        label: "Shut down"
                        SBtn { label: win.armed === "off" ? "Click again" : "Shut down"; danger: true; onClicked: win.confirm("off", () => Quickshell.execDetached(["systemctl", "poweroff"])) }
                    }
                }
            }

            // ================= DEVICES =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "devices"

                SSection {
                    title: "Display"
                    SRow {
                        label: "Brightness"
                        desc: "Backlight level (brightnessctl)."
                        SSlider { value: win.brightness; onMoved: v => { win.brightness = v; briTimer.v = v; briTimer.restart() } }
                    }
                }
                SSection {
                    title: "Sound"
                    SRow {
                        label: "Volume"
                        desc: "Default output device."
                        SSlider { value: win.audio ? Math.min(1, win.audio.volume) : 0; onMoved: v => { if (win.audio) win.audio.volume = v } }
                    }
                    SRow {
                        label: "Mute output"
                        SToggle { checked: win.audio ? win.audio.muted : false; onToggled: v => { if (win.audio) win.audio.muted = v } }
                    }
                    SRow {
                        label: "Microphone"
                        desc: "Toggle the default microphone mute."
                        SBtn { label: "Toggle mute"; onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]) }
                    }
                }
                SSection {
                    title: "Keyboard"
                    SRow { label: "Current layout"; SVal { text: win.layoutName || "…" } }
                    SRow {
                        label: "Switch layout"
                        desc: "Go to the next keyboard layout."
                        SBtn { label: "Next layout"; onClicked: { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]); kbTimer.restart() } }
                    }
                }
            }

            // ================= POWER & IDLE =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "power"

                SSection {
                    title: "Idle manager"
                    SRow {
                        label: "Idle manager"
                        desc: "Dims, locks, turns the screen off and suspends after you stop using the computer. Order: dim, lock, screen off, suspend."
                        SToggle { checked: Settings.idleEnabled; onToggled: v => Settings.set("idleEnabled", v) }
                    }
                    SRow {
                        label: "Keep awake"
                        desc: "Pause every idle action until you switch this off. Not saved between sessions."
                        SToggle { checked: Settings.idleKeepAwake; onToggled: v => Settings.idleKeepAwake = v }
                    }
                    SRow {
                        label: "Respect inhibitors"
                        desc: "Do nothing while a video plays or an app asks the system to stay awake."
                        SToggle { checked: Settings.idleRespectInhibit; onToggled: v => Settings.set("idleRespectInhibit", v) }
                    }
                }
                SSection {
                    title: "Timers"
                    SRow {
                        label: "Dim screen after"
                        desc: "Counted from your last activity. Off = never."
                        SSlider { value: Settings.idleDimSec / 600; readout: win.fmt(Settings.idleDimSec); onMoved: v => Settings.set("idleDimSec", Math.round(v * 20) * 30) }
                    }
                    SRow {
                        label: "Dim level"
                        desc: "Brightness while the screen is dimmed."
                        SSlider { value: (Settings.idleDimLevel - 5) / 55; readout: Settings.idleDimLevel + "%"; onMoved: v => Settings.set("idleDimLevel", Math.round(5 + v * 55)) }
                    }
                    SRow {
                        label: "Lock after"
                        desc: "Starts the lock screen."
                        SSlider { value: Settings.idleLockSec / 3600; readout: win.fmt(Settings.idleLockSec); onMoved: v => Settings.set("idleLockSec", Math.round(v * 60) * 60) }
                    }
                    SRow {
                        label: "Screen off after"
                        desc: "Turns the display off; any movement turns it back on."
                        SSlider { value: Settings.idleOffSec / 3600; readout: win.fmt(Settings.idleOffSec); onMoved: v => Settings.set("idleOffSec", Math.round(v * 60) * 60) }
                    }
                    SRow {
                        label: "Suspend after"
                        desc: "Puts the computer to sleep."
                        SSlider { value: Settings.idleSuspendSec / 7200; readout: win.fmt(Settings.idleSuspendSec); onMoved: v => Settings.set("idleSuspendSec", Math.round(v * 24) * 300) }
                    }
                    SRow {
                        label: "Lock before suspend"
                        desc: "Starts the lock screen first so you wake up to a locked session."
                        SToggle { checked: Settings.idleLockBeforeSuspend; onToggled: v => Settings.set("idleLockBeforeSuspend", v) }
                    }
                }
                SSection {
                    title: "Commands"
                    SRow {
                        label: "Lock command"
                        desc: "Run by the lock timer and the Lock buttons."
                        SText { text: Settings.lockCmd; placeholder: "qs -c lock"; onEdited: v => Settings.set("lockCmd", v.trim()) }
                    }
                    SRow {
                        label: "Screen off command"
                        desc: "Run when the screen-off timer fires."
                        SText { text: Settings.idleOffCmd; placeholder: "hyprctl dispatch dpms off"; onEdited: v => Settings.set("idleOffCmd", v.trim()) }
                    }
                    SRow {
                        label: "Screen on command"
                        desc: "Run at the first movement after the screen turned off."
                        SText { text: Settings.idleOnCmd; placeholder: "hyprctl dispatch dpms on"; onEdited: v => Settings.set("idleOnCmd", v.trim()) }
                    }
                    SRow {
                        label: "Suspend command"
                        SText { text: Settings.suspendCmd; placeholder: "systemctl suspend"; onEdited: v => Settings.set("suspendCmd", v.trim()) }
                    }
                }
                SSection {
                    title: "Test"
                    SRow {
                        label: "Lock now"
                        SBtn { label: "Lock"; onClicked: win.idle("lock") }
                    }
                    SRow {
                        label: "Dim preview"
                        desc: "Dims the screen for 3 seconds."
                        SBtn { label: "Test dim"; onClicked: win.idle("dimtest") }
                    }
                    SRow {
                        label: "Suspend now"
                        SBtn { label: win.armed === "suspend" ? "Click again" : "Suspend"; danger: true; onClicked: win.confirm("suspend", () => win.idle("suspend")) }
                    }
                }
            }

            // ================= NETWORK =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "network"

                SSection {
                    title: "Wi-Fi"
                    SRow {
                        label: "Wi-Fi"
                        desc: win.wifiActive !== "" ? "Connected to " + win.wifiActive : "Not connected."
                        SToggle { checked: win.wifiOn; onToggled: v => { win.wifiOn = v; Quickshell.execDetached(["nmcli", "radio", "wifi", v ? "on" : "off"]); netTimer.restart() } }
                    }
                    SRow {
                        label: "Scan"
                        desc: "Look for networks again."
                        Row {
                            spacing: 6
                            SBtn { label: "Rescan"; onClicked: { Quickshell.execDetached(["nmcli", "dev", "wifi", "rescan"]); netTimer.restart() } }
                            SBtn { label: "Network editor"; onClicked: win.inTerminal("nmtui") }
                        }
                    }
                    Repeater {
                        model: win.wifiList
                        delegate: SRow {
                            required property var modelData
                            label: modelData.ssid + (modelData.use ? "  (connected)" : "")
                            desc: modelData.sig + "% signal · " + (modelData.sec !== "" ? modelData.sec : "open")
                            SBtn {
                                visible: !modelData.use
                                label: "Connect"
                                onClicked: { Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid]); netTimer.restart() }
                            }
                        }
                    }
                }
                SSection {
                    title: "Bluetooth"
                    SRow {
                        label: "Bluetooth"
                        SToggle { checked: win.btOn; onToggled: v => { win.btOn = v; Quickshell.execDetached(["bluetoothctl", "power", v ? "on" : "off"]); btTimer.restart() } }
                    }
                    Repeater {
                        model: win.btDevices
                        delegate: SRow {
                            required property var modelData
                            label: modelData.name
                            desc: modelData.mac
                            Row {
                                spacing: 6
                                SBtn { label: "Connect"; onClicked: { Quickshell.execDetached(["bluetoothctl", "connect", modelData.mac]); btTimer.restart() } }
                                SBtn { label: "Disconnect"; onClicked: { Quickshell.execDetached(["bluetoothctl", "disconnect", modelData.mac]); btTimer.restart() } }
                            }
                        }
                    }
                }
            }

            // ================= PERSONALIZATION =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "personal"

                SSection {
                    title: "Look"
                    SRow {
                        label: "Accent color"
                        desc: "Used for highlights, borders and the cat's collar."
                        SChoice {
                            options: Settings.presetIds.map(id => Settings.presets[id].name)
                            current: Settings.presetIds.indexOf(Settings.preset)
                            onPicked: i => Settings.set("preset", Settings.presetIds[i])
                        }
                    }
                    SRow {
                        label: "Clock format"
                        desc: "Taskbar clock."
                        SChoice { options: ["24 hour", "12 hour"]; current: Settings.clock24 ? 0 : 1; onPicked: i => Settings.set("clock24", i === 0) }
                    }
                    SRow {
                        label: "CPU cat"
                        desc: "Pixel cat in the taskbar: sleeps when idle, runs when busy."
                        SToggle { checked: Settings.cat; onToggled: v => Settings.set("cat", v) }
                    }
                    SRow {
                        label: "Window titlebars"
                        desc: "Pixel titlebar with app icon above every window."
                        SToggle { checked: Store.titlebars; onToggled: v => Store.titlebars = v }
                    }
                }
                SSection {
                    title: "Wallpaper"
                    SRow {
                        label: "Current"
                        desc: Wallpaper.count + " pictures in ~/Pictures/Wallpapers"
                        SVal { text: Wallpaper.current ? Wallpaper.current.split("/").pop() : "—" }
                    }
                    SRow {
                        label: "Change"
                        Row {
                            spacing: 6
                            SBtn { label: "Previous"; onClicked: Wallpaper.prev() }
                            SBtn { label: "Next"; onClicked: Wallpaper.next() }
                            SBtn { label: "Random"; onClicked: Wallpaper.random() }
                        }
                    }
                    SRow {
                        label: "Auto-change"
                        desc: "Pick a new wallpaper on a timer."
                        SChoice {
                            readonly property var mins: [0, 5, 15, 60]
                            options: ["Off", "5 min", "15 min", "1 hour"]
                            current: Math.max(0, mins.indexOf(Wallpaper.autoMinutes))
                            onPicked: i => { Wallpaper.autoMinutes = mins[i]; Wallpaper.save() }
                        }
                    }
                }
            }

            // ================= DESKTOP =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "desktop"

                SSection {
                    title: "Widgets"
                    Repeater {
                        model: [["clock", "Clock"], ["media", "Media player"], ["sys", "System monitor"], ["workspaces", "Workspaces"], ["notes", "Notes"], ["wallpaper", "Wallpaper picker"]]
                        delegate: SRow {
                            required property var modelData
                            label: modelData[1]
                            desc: "Show this widget on the desktop."
                            SToggle {
                                checked: Store.hiddenTypes[modelData[0]] !== true
                                onToggled: v => { if ((Store.hiddenTypes[modelData[0]] !== true) !== v) Store.toggleType(modelData[0]) }
                            }
                        }
                    }
                }
                SSection {
                    title: "Layout"
                    SRow {
                        label: "Edit mode"
                        desc: "Drag and resize widgets. Esc to finish."
                        SBtn { label: "Edit desktop"; onClicked: Store.editing = true }
                    }
                    SRow {
                        label: "Focus mode"
                        desc: "Hide every widget and the taskbar."
                        SToggle { checked: Store.hidden; onToggled: v => Store.hidden = v }
                    }
                    SRow {
                        label: "Dock notes"
                        desc: "Move the notes widget to a corner."
                        Row {
                            spacing: 6
                            SBtn { label: "Bottom right"; onClicked: Store.dock("notes", "br") }
                            SBtn { label: "Top left"; onClicked: Store.dock("notes", "tl") }
                        }
                    }
                }
            }

            // ================= WINDOWS =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "windows"

                SSection {
                    title: "Windows"
                    SRow {
                        label: "Titlebars"
                        desc: "Pixel titlebars with app icon, name and buttons."
                        SToggle { checked: Store.titlebars; onToggled: v => Store.titlebars = v }
                    }
                    SRow {
                        label: "Animations"
                        desc: "Window and workspace animations. Applies until Hyprland reloads; edit look.lua to keep."
                        SToggle { checked: win.winAnim; onToggled: v => { win.winAnim = v; win.hypr("animations:enabled", v ? 1 : 0) } }
                    }
                    SRow {
                        label: "Gap between windows"
                        desc: "Applies until Hyprland reloads."
                        SSlider { max: 40; suffix: " px"; value: win.gapsIn / 40; onMoved: v => { win.gapsIn = Math.round(v * 40); win.hypr("general:gaps_in", win.gapsIn) } }
                    }
                    SRow {
                        label: "Gap to screen edge"
                        desc: "Applies until Hyprland reloads."
                        SSlider { max: 40; suffix: " px"; value: win.gapsOut / 40; onMoved: v => { win.gapsOut = Math.round(v * 40); win.hypr("general:gaps_out", win.gapsOut) } }
                    }
                    SRow {
                        label: "Corner rounding"
                        desc: "Pixel titlebars look best at 0. Applies until Hyprland reloads."
                        SSlider { max: 24; suffix: " px"; value: win.rounding / 24; onMoved: v => { win.rounding = Math.round(v * 24); win.hypr("decoration:rounding", win.rounding) } }
                    }
                }
            }

            // ================= APPS =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "apps"

                SSection {
                    title: "Default apps"
                    SRow {
                        label: "Terminal"
                        desc: "Command used by the START menu and update buttons."
                        SText { text: Settings.termCmd; placeholder: "kitty"; onEdited: v => Settings.set("termCmd", v.trim() || "kitty") }
                    }
                    SRow {
                        label: "File manager"
                        desc: "Command used by the START menu."
                        SText { text: Settings.filesCmd; placeholder: "nautilus"; onEdited: v => Settings.set("filesCmd", v.trim() || "nautilus") }
                    }
                }
                SSection {
                    title: "Pinned apps"
                    SRow {
                        show: Store.appPinned.length === 0
                        label: "Nothing pinned"
                        desc: "Right-click an app in the launcher to pin it."
                    }
                    Repeater {
                        model: Store.appPinned
                        delegate: SRow {
                            required property string modelData
                            readonly property var entry: DesktopEntries.byId(modelData)
                            label: entry ? entry.name : modelData
                            desc: modelData
                            SBtn { label: "Unpin"; onClicked: Store.togglePin(modelData) }
                        }
                    }
                }
                SSection {
                    title: "Launcher data"
                    SRow {
                        label: "Reset pins and history"
                        desc: "Clears pinned apps and the most-used list."
                        SBtn { label: win.armed === "apps" ? "Click again" : "Reset"; danger: true; onClicked: win.confirm("apps", () => Store.clearApps()) }
                    }
                }
            }

            // ================= NOTIFICATIONS =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "notifications"

                SSection {
                    title: "Popups"
                    SRow {
                        label: "Do not disturb"
                        desc: "No popups. Critical ones still show; history keeps everything."
                        SToggle { checked: Notifs.dnd; onToggled: v => Notifs.dnd = v }
                    }
                    SRow {
                        label: "Popup time"
                        desc: "How long a normal notification stays on screen."
                        SChoice {
                            readonly property var secs: [3, 6, 10, 15]
                            options: ["3 s", "6 s", "10 s", "15 s"]
                            current: Math.max(0, secs.indexOf(Settings.popupSec))
                            onPicked: i => Settings.set("popupSec", secs[i])
                        }
                    }
                    SRow {
                        label: "Test"
                        desc: "Send a sample notification."
                        SBtn { label: "Send test"; onClicked: Quickshell.execDetached(["notify-send", "-a", "Clover", "Test notification", "This is how popups look."]) }
                    }
                }
                SSection {
                    title: "History"
                    SRow { label: "Stored notifications"; SVal { text: String(Notifs.count) } }
                    SRow {
                        label: "Clear history"
                        SBtn { label: "Clear all"; danger: true; onClicked: Notifs.clear() }
                    }
                    SRow {
                        label: "Open history"
                        desc: "Same as clicking the bell in the taskbar."
                        SBtn { label: "Open"; onClicked: Store.notifCenter = true }
                    }
                }
            }

            // ================= ACCESSIBILITY =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "access"

                SSection {
                    title: "Display"
                    SRow {
                        label: "Reduce motion"
                        desc: "Turns off the cat's running, battery steam and sparks, and the floating z."
                        SToggle { checked: Settings.reduceMotion; onToggled: v => Settings.set("reduceMotion", v) }
                    }
                    SRow {
                        label: "High contrast text"
                        desc: "Brighter secondary text everywhere."
                        SToggle { checked: Settings.highContrast; onToggled: v => Settings.set("highContrast", v) }
                    }
                }
            }

            // ================= UPDATES (Arch Linux) =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "updates"

                SSection {
                    title: "Status"
                    SRow {
                        label: "Repository updates"
                        desc: win.updBusy ? "Checking…" : (win.updRepo.length > 0 ? "pacman packages waiting for an upgrade." : "System is up to date.")
                        SVal { text: win.updBusy ? "…" : String(win.updRepo.length) }
                    }
                    SRow {
                        label: "AUR updates"
                        desc: "Needs paru or yay."
                        SVal { text: win.updBusy ? "…" : String(win.updAur.length) }
                    }
                    SRow {
                        label: "Last full upgrade"
                        SVal { text: win.lastUpgrade !== "" ? win.lastUpgrade : "unknown" }
                    }
                    SRow {
                        label: "Check now"
                        desc: "Uses checkupdates from pacman-contrib."
                        SBtn { label: "Check"; onClicked: win.checkUpdates() }
                    }
                    SRow {
                        show: win.updRepo.length + win.updAur.length > 0
                        label: "Packages"
                        desc: win.updRepo.concat(win.updAur).slice(0, 12).join("\n") + (win.updRepo.length + win.updAur.length > 12 ? "\n… and " + (win.updRepo.length + win.updAur.length - 12) + " more" : "")
                    }
                }
                SSection {
                    title: "Actions"
                    SRow {
                        label: "Update system"
                        desc: "Runs paru -Syu (or sudo pacman -Syu) in your terminal."
                        SBtn { label: "Update"; onClicked: win.inTerminal("if command -v paru >/dev/null; then paru -Syu; else sudo pacman -Syu; fi") }
                    }
                    SRow {
                        label: "Refresh mirrors"
                        desc: "Ranks the 20 newest mirrors with reflector."
                        SBtn { label: "Run"; onClicked: win.inTerminal("sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist") }
                    }
                    SRow {
                        label: "Clean package cache"
                        desc: "Keeps the last 2 versions of each package (paccache)."
                        SBtn { label: "Clean"; onClicked: win.inTerminal("sudo paccache -rk2") }
                    }
                    SRow {
                        label: "Remove orphans"
                        desc: "Uninstalls packages nothing depends on."
                        SBtn { label: "Remove"; onClicked: win.inTerminal("pacman -Qdtq | sudo pacman -Rns -") }
                    }
                    SRow {
                        label: "Arch Linux news"
                        desc: "Read before big upgrades."
                        SBtn { label: "Open"; onClicked: Quickshell.execDetached(["xdg-open", "https://archlinux.org/news/"]) }
                    }
                }
            }

            // ================= ABOUT =================
            Column {
                width: parent.width
                spacing: 14
                visible: win.searching || win.page === "about"

                SSection {
                    title: "Clover"
                    SRow { label: "Shell"; desc: "Widget desktop for Hyprland on Quickshell."; SVal { text: "Clover" } }
                    SRow { label: "Quickshell"; SVal { text: win.qsVersion !== "" ? win.qsVersion : "…" } }
                    SRow { label: "Config folder"; SVal { text: "~/.config/quickshell/clover" } }
                    SRow {
                        label: "Open config folder"
                        SBtn { label: "Open"; onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/quickshell/clover"]) }
                    }
                    SRow {
                        label: "Reset all settings"
                        desc: "Back to defaults (orange, cat on, titlebars on)."
                        SBtn { label: win.armed === "reset" ? "Click again" : "Reset"; danger: true; onClicked: win.confirm("reset", () => Settings.resetAll()) }
                    }
                }
            }
        }
    }

    Timer { id: restoreTimer; interval: 400; onTriggered: Settings.reload() }
}
