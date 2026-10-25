import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    required property int ws

    // widget rect in screen coordinates (corner "br" stores distances from right/bottom)
    function rect(c) {
        return c.corner === "br"
            ? { x: width - c.x - c.w, y: height - c.y - c.h, w: c.w, h: c.h }
            : { x: c.x, y: c.y, w: c.w, h: c.h }
    }

    visible: Store.editing
    color: "#40000000"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.namespace: "clover-edit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Store.editing = false

        // snap grid
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d")
                c.clearRect(0, 0, width, height)
                c.fillStyle = "#40ffffff"
                for (let x = 0; x < width; x += Store.grid)
                    for (let y = 0; y < height; y += Store.grid)
                        c.fillRect(x, y, 2, 2)
            }
        }

        // drag / resize: one area, hit-tested, so Repeater rebuilds can't break a drag
        MouseArea {
            id: ma
            anchors.fill: parent

            property string dragId: ""
            property string mode: ""
            property real px: 0
            property real py: 0
            property var start: null
            property var startRect: null

            function hit(mx, my) {
                const ids = Store.idsFor(win.ws)
                for (let k = ids.length - 1; k >= 0; k--) {
                    const c = Store.find(ids[k])
                    if (!c) continue
                    const r = win.rect(c)
                    if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h)
                        return c
                }
                return null
            }

            onPressed: mouse => {
                const c = hit(mouse.x, mouse.y)
                if (!c) return
                dragId = c.id
                start = c
                px = mouse.x
                py = mouse.y
                const r = win.rect(c)
                startRect = r
                mode = (mouse.x > r.x + r.w - 26 && mouse.y > r.y + r.h - 26) ? "resize" : "move"
            }
            onPositionChanged: mouse => {
                if (dragId === "") return
                const g = Store.grid
                const snap = v => Math.round(v / g) * g
                const dx = mouse.x - px
                const dy = mouse.y - py
                const br = start.corner === "br"
                const W = win.width
                const H = win.height
                const r0 = startRect
                if (mode === "move") {
                    const L = snap(r0.x + dx)
                    const T = snap(r0.y + dy)
                    Store.patch(dragId, br
                        ? { x: Math.max(0, W - L - r0.w), y: Math.max(0, H - T - r0.h) }
                        : { x: Math.max(0, L), y: Math.max(0, T) })
                } else {
                    const w = Math.max(g * 5, snap(r0.w + dx))
                    const h = Math.max(g * 3, snap(r0.h + dy))
                    Store.patch(dragId, br
                        ? { w: w, h: h, x: Math.max(0, W - r0.x - w), y: Math.max(0, H - r0.y - h) }
                        : { w: w, h: h })
                }
            }
            onReleased: dragId = ""
        }

        // outlines, handles, chips
        Repeater {
            model: Store.idsFor(win.ws)
            delegate: Item {
                id: d
                required property string modelData
                readonly property var c: Store.find(modelData)

                readonly property var r: c ? win.rect(c) : null

                visible: c !== null
                x: r ? r.x : 0
                y: r ? r.y : 0
                width: r ? r.w : 0
                height: r ? r.h : 0

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.accent
                }
                Rectangle {
                    x: parent.width - 22
                    y: parent.height - 22
                    width: 14
                    height: 14
                    radius: 0
                    color: Theme.accent
                }
                Row {
                    anchors { top: parent.top; right: parent.right; margins: 8 }
                    spacing: 4
                    Repeater {
                        model: ["scope", "corner", "pin", "del"]
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            width: 42
                            height: 22
                            radius: Theme.radius
                            color: cm.pressed ? Theme.accentDim : "#e60a0a0a"
                            border.width: 1
                            border.color: Theme.line
                            Text {
                                anchors.centerIn: parent
                                color: "white"
                                font.pixelSize: 11
                                text: chip.modelData === "scope" ? (d.c && d.c.scope === "global" ? "global" : "ws")
                                    : chip.modelData === "corner" ? (d.c && d.c.corner === "br" ? "br" : "tl")
                                    : chip.modelData === "pin" ? (d.c && d.c.pinned ? "pinned" : "pin")
                                    : "\u2715"
                            }
                            MouseArea {
                                id: cm
                                anchors.fill: parent
                                onClicked: {
                                    if (chip.modelData === "scope") Store.toggleScope(d.modelData, win.ws)
                                    else if (chip.modelData === "corner") {
                                        const rr = win.rect(d.c)
                                        Store.patch(d.modelData, d.c.corner === "br"
                                            ? { corner: "tl", x: rr.x, y: rr.y }
                                            : { corner: "br", x: win.width - rr.x - d.c.w, y: win.height - rr.y - d.c.h })
                                    }
                                    else if (chip.modelData === "pin") Store.patch(d.modelData, { pinned: !(d.c && d.c.pinned) })
                                    else Store.remove(d.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // hint
        Text {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 24 }
            color: "white"
            font.pixelSize: 14
            style: Text.Raised
            styleColor: "#80000000"
            text: "Edit mode  \u00B7  drag to move  \u00B7  corner to resize  \u00B7  Esc to exit"
        }

        // add widgets
        Row {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 40 }
            spacing: 10
            Repeater {
                model: ["clock", "media", "sys", "workspaces", "notes", "wallpaper"]
                delegate: Item {
                    id: add
                    required property string modelData
                    width: 120
                    height: 36
                    Btn {
                        anchors.fill: parent
                        solid: true
                        label: "+ " + add.modelData
                        onClicked: Store.add(add.modelData, win.ws)
                    }
                }
            }
        }
    }
}
