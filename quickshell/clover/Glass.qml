import QtQuick

// Flat tinted glass: translucent fill only, no rim, no gloss.
// Real blur comes from Hyprland (layer_rule blur).
Item {
    id: root

    property color tint: "#3fa7ff"
    property real radius: 20
    property real strength: 0.34
    default property alias content: slot.data

    function tinted(alpha) {
        return Qt.rgba(tint.r, tint.g, tint.b, alpha)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.tinted(root.strength + 0.04) }
            GradientStop { position: 1.0; color: root.tinted(root.strength - 0.04) }
        }
    }

    Item {
        id: slot
        anchors.fill: parent
        anchors.margins: 14
    }
}
