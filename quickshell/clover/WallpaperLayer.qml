import QtQuick
import Quickshell
import Quickshell.Wayland

// Draws the wallpaper (crossfade) and accepts dropped images anywhere on the bare desktop.
PanelWindow {
    id: win

    color: "black"
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.namespace: "clover-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: stack
        anchors.fill: parent

        property var cur: img1
        property var nxt: img2
        property bool pending: false

        function show(path) {
            if (path === "") return
            const url = "file://" + path
            if (cur.source.toString() === "") {
                cur.source = url
                cur.opacity = 1
                return
            }
            if (cur.source.toString() === url) return
            nxt.opacity = 0
            nxt.source = url
            pending = true
            if (nxt.status === Image.Ready) ready(nxt)
        }
        function ready(img) {
            if (!pending || img !== nxt || img.status !== Image.Ready) return
            pending = false
            nxt.z = 1
            fade.restart()
        }

        Component.onCompleted: show(Wallpaper.current)
        Connections {
            target: Wallpaper
            function onCurrentChanged() { stack.show(Wallpaper.current) }
        }

        Image {
            id: img1
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0
            onStatusChanged: stack.ready(img1)
        }
        Image {
            id: img2
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0
            onStatusChanged: stack.ready(img2)
        }

        NumberAnimation {
            id: fade
            target: stack.nxt
            property: "opacity"
            from: 0
            to: 1
            duration: 450
            easing.type: Easing.OutCubic
            onFinished: {
                const old = stack.cur
                stack.cur = stack.nxt
                stack.nxt = old
                old.opacity = 0
                old.z = 0
                stack.cur.z = 0
            }
        }
    }

    DropArea {
        anchors.fill: parent
        z: 2
        onDropped: d => {
            if (d.hasUrls) {
                Wallpaper.addUrls(d.urls)
                d.accept()
            }
        }
    }
}
