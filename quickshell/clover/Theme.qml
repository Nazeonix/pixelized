pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property bool wp: Settings.useWp
    readonly property color bg: wp ? Settings.wp.bg : "#8c050505"
    readonly property color line: wp ? Settings.wp.line : "#38ffffff"
    readonly property color text: wp ? Settings.wp.text : "#f5f5f5"
    readonly property color dim: Settings.highContrast ? (wp ? Settings.wp.text : "#c8c8c8") : (wp ? Settings.wp.dim : "#8c8c8c")
    readonly property color accent: Settings.accent
    readonly property color accentDim: Settings.accentDim
    readonly property int radius: 6
    readonly property string mono: "JetBrains Mono"
}
