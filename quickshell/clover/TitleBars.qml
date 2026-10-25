import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Pixel titlebars for every window.
//  * a transparent strip at the top of each screen reserves room for the bars
//  * one TitleBar per Hyprland window, positioned from its geometry (polled ~20 Hz)
// Toggle: qs -c clover ipc call clover titlebars
Scope {
    readonly property int barH: 28

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: Store.titlebars
            anchors { left: true; right: true; top: true }
            implicitHeight: 28
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 28
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "clover-titlebar-reserve"
        }
    }

    Variants {
        model: Hyprland.toplevels.values

        TitleBar {
            required property var modelData
            tl: modelData
        }
    }

    // follow window moves / resizes / workspace switches
    Timer {
        interval: 50
        repeat: true
        running: Store.titlebars
        onTriggered: Hyprland.refreshToplevels()
    }
    Timer {
        interval: 250
        repeat: true
        running: Store.titlebars
        onTriggered: Hyprland.refreshMonitors()
    }
}
