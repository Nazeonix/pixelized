import QtQuick

Panel {
    id: root

    title: "Wallpaper // local"
    status: Wallpaper.count + " images"
    statusColor: dz.containsDrag ? Theme.accent : Theme.dim

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: row.top; bottomMargin: 10 }
        color: "#55000000"
        radius: Theme.radius
        border.width: 1
        border.color: dz.containsDrag ? Theme.accent : Theme.line
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 640
        }
        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            visible: dz.containsDrag
        }
        Mono {
            anchors.centerIn: parent
            visible: dz.containsDrag || Wallpaper.current === ""
            text: dz.containsDrag ? "DROP TO ADD" : "DROP IMAGE HERE"
            font.pixelSize: 12
            font.letterSpacing: 1.5
        }
        DropArea {
            id: dz
            anchors.fill: parent
            onDropped: d => {
                if (d.hasUrls) {
                    Wallpaper.addUrls(d.urls)
                    d.accept()
                }
            }
        }
    }

    Row {
        id: row
        anchors { left: parent.left; bottom: parent.bottom }
        spacing: 8
        Btn { label: "Prev"; onClicked: Wallpaper.prev() }
        Btn { label: "Next"; onClicked: Wallpaper.next() }
        Btn { label: "Random"; accent: true; onClicked: Wallpaper.random() }
    }
}
