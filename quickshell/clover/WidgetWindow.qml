import QtQuick
import Quickshell
import Quickshell.Wayland

// One layer-shell surface per widget: click-through everywhere else, for free.
PanelWindow {
    id: win

    required property string modelData
    readonly property var cfg: Store.find(modelData)

    readonly property bool off: Store.hidden || (cfg !== null && Store.hiddenTypes[cfg.type] === true)

    visible: cfg !== null && !(off && body.opacity < 0.01)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "clover"
    // notes need keyboard focus, which compositors only give to Top/Overlay layers
    WlrLayershell.layer: cfg && (cfg.pinned || cfg.type === "notes") ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // corner "br": x/y are distances from the right/bottom edge; otherwise from left/top
    readonly property bool br: cfg !== null && cfg.corner === "br"
    anchors { left: !br; top: !br; right: br; bottom: br }
    margins {
        left: cfg && !br ? cfg.x : 0
        top: cfg && !br ? cfg.y : 0
        right: cfg && br ? cfg.x : 0
        bottom: cfg && br ? cfg.y : 0
    }
    implicitWidth: cfg ? cfg.w : 200
    implicitHeight: cfg ? cfg.h : 100

    Item {
        id: body
        anchors.fill: parent

        property bool shown: false
        Component.onCompleted: shown = true
        opacity: shown && !win.off ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                switch (win.cfg ? win.cfg.type : "") {
                case "clock": return clockC
                case "media": return mediaC
                case "sys": return sysC
                case "workspaces": return wsC
                case "notes": return notesC
                case "wallpaper": return wallC
                }
                return null
            }
        }
    }

    Component { id: clockC; ClockWidget {} }
    Component { id: mediaC; MediaWidget {} }
    Component { id: sysC; SysWidget {} }
    Component { id: wsC; WorkspacesWidget {} }
    Component { id: notesC; NotesWidget {} }
    Component { id: wallC; WallpaperWidget {} }
}
