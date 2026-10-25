import QtQuick

// Hard 1px pixel bevel: light top/left + dark bottom/right when raised, flipped when down.
Item {
    id: root

    property bool down: false
    property color fill: "transparent"
    property color edge: Theme.line
    readonly property color hi: "#33ffffff"
    readonly property color lo: "#66000000"

    Rectangle { anchors.fill: parent; color: root.fill; border.width: 1; border.color: root.edge }
    Rectangle { x: 1; y: 1; width: root.width - 2; height: 1; color: root.down ? root.lo : root.hi }
    Rectangle { x: 1; y: 1; width: 1; height: root.height - 2; color: root.down ? root.lo : root.hi }
    Rectangle { x: 1; y: root.height - 2; width: root.width - 2; height: 1; color: root.down ? root.hi : root.lo }
    Rectangle { x: root.width - 2; y: 1; width: 1; height: root.height - 2; color: root.down ? root.hi : root.lo }
}
