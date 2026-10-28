import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Low-battery warning panel (top centre). Levels: 1 low, 2 very low, 3 critical.
PanelWindow {
    id: win

    readonly property bool here: Hyprland.focusedMonitor?.name === screen?.name
    readonly property int lvl: Store.batLevel
    readonly property int pct: Store.batPct
    property bool blink: false

    visible: lvl > 0 && here
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    margins.top: 44
    implicitHeight: 130
    mask: Region { item: panel }
    WlrLayershell.namespace: "clover-battery"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string heading: lvl >= 3 ? "BATTERY CRITICAL" : (lvl === 2 ? "BATTERY VERY LOW" : "LOW BATTERY")
    readonly property string advice: lvl >= 3 ? "Plug in the charger now!" : (lvl === 2 ? "Save your work and plug in." : "Plug in the charger soon.")

    Timer {
        interval: 450
        repeat: true
        running: win.visible && win.lvl >= 2 && !Settings.reduceMotion
        onTriggered: win.blink = !win.blink
    }
    // levels 1 and 2 hide by themselves, critical stays until dismissed or plugged in
    Timer {
        interval: win.lvl === 1 ? 12000 : 20000
        running: win.visible && win.lvl > 0 && win.lvl < 3
        onTriggered: Store.batLevel = 0
    }

    Item {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: 420
        height: 98

        // hard pixel shadow
        Rectangle { x: parent.width; y: 3; width: 3; height: parent.height; color: "#80000000" }
        Rectangle { x: 3; y: parent.height; width: parent.width; height: 3; color: "#80000000" }

        Bevel {
            anchors.fill: parent
            fill: (win.lvl >= 3 && win.blink) ? Theme.accentDim : Theme.bg
            edge: (win.lvl >= 2 && win.blink) ? Theme.text : Theme.accent
        }

        // icon box
        Item {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 62
            height: 62
            Bevel { anchors.fill: parent; down: true; fill: "#59000000"; edge: Theme.line }
            Pix {
                anchors.centerIn: parent
                px: 3
                rows: Icons.bm.batt
                tone: (win.lvl >= 2 && win.blink) ? Theme.text : Theme.accent
            }
        }

        Mono {
            x: 86
            y: 14
            text: win.heading
            color: win.lvl >= 2 ? Theme.accent : Theme.text
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 3
        }
        Mono {
            x: 86
            y: 36
            text: win.pct + "% left. " + win.advice
            color: Theme.dim
            font.pixelSize: 10
        }

        // charge bar
        Row {
            x: 86
            y: 62
            spacing: 2
            Repeater {
                model: 20
                delegate: Rectangle {
                    required property int index
                    width: 14
                    height: 14
                    color: index < Math.max(win.pct > 0 ? 1 : 0, Math.round(win.pct / 100 * 20)) ? Theme.accent : "#1affffff"
                }
            }
        }

        // close
        Item {
            anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 10 }
            width: 22
            height: 20
            Bevel { anchors.fill: parent; down: xa.pressed; fill: xa.containsMouse ? Theme.accent : "transparent" }
            Pix { anchors.centerIn: parent; px: 1; rows: ["##...##", ".##.##.", "..###..", ".##.##.", "##...##"] }
            MouseArea { id: xa; anchors.fill: parent; hoverEnabled: true; onClicked: Store.batLevel = 0 }
        }
    }
}
