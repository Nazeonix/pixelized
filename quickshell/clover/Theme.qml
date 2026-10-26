pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color bg: "#8c050505"
    readonly property color line: "#38ffffff"
    readonly property color text: "#f5f5f5"
    readonly property color dim: Settings.highContrast ? "#c8c8c8" : "#8c8c8c"
    readonly property color accent: Settings.accent
    readonly property color accentDim: Settings.accentDim
    readonly property int radius: 6
    readonly property string mono: "JetBrains Mono"
}
