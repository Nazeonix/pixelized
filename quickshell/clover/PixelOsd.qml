import QtQuick

// Retro pixel OSD: framed panel, pixel icon box, segmented bar, big percent.
// Used by VolumeOsdLayer and BrightnessOsdLayer.
Item {
    id: osd

    property var iconRows: []
    property string label: ""
    property real value: 0              // 0..1
    property bool muted: false
    property bool alert: false          // draw everything in the accent color
    property string valueText: ""      // replaces the percent on the right
    property int segs: 20

    readonly property int lit: muted ? 0 : Math.round(Math.min(1, value) * segs)
    readonly property color tint: (muted || alert || value > 0.85) ? Theme.accent : Theme.text

    width: 310
    height: 62

    // hard pixel shadow
    Rectangle { x: parent.width; y: 3; width: 3; height: parent.height; color: "#80000000" }
    Rectangle { x: 3; y: parent.height; width: parent.width; height: 3; color: "#80000000" }

    Bevel {
        anchors.fill: parent
        fill: Theme.bg
        edge: Theme.accent
    }

    // icon box
    Item {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        Bevel { anchors.fill: parent; down: true; fill: "#59000000"; edge: Theme.line }
        Pix {
            anchors.centerIn: parent
            rows: osd.iconRows
            tone: osd.tint
            tone2: osd.alert ? Theme.text : Theme.accent
        }
    }

    Mono {
        x: 62
        y: 9
        text: osd.label
        color: osd.muted ? Theme.accent : Theme.dim
        font.pixelSize: 9
        font.letterSpacing: 3
    }
    Mono {
        anchors { right: parent.right; rightMargin: 14 }
        y: 7
        text: osd.valueText !== "" ? osd.valueText : (osd.muted ? "--" : Math.round(osd.value * 100) + "%")
        color: osd.tint
        font.pixelSize: 13
        font.weight: Font.Bold
        font.letterSpacing: 1
    }

    // segmented bar
    Row {
        x: 62
        y: 28
        spacing: 2

        Repeater {
            model: osd.segs
            delegate: Item {
                id: seg
                required property int index
                readonly property bool on: index < osd.lit
                width: Math.floor((218 - (osd.segs - 1) * 2) / osd.segs)
                height: 22

                Rectangle {
                    anchors.fill: parent
                    color: seg.on ? ((osd.alert || seg.index >= Math.floor(osd.segs * 0.85)) ? Theme.accent : Theme.text) : "#1affffff"
                }
                // lit segments get a bright top edge, unlit ones a dark floor: chunky retro bevel
                Rectangle { visible: seg.on; width: parent.width; height: 2; color: "#99ffffff" }
                Rectangle { visible: seg.on; y: parent.height - 2; width: parent.width; height: 2; color: "#55000000" }
            }
        }
    }
}
