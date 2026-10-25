import QtQuick

Panel {
    id: root

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function load() {
        const n = Notes.notes[Notes.current]
        titleIn.text = n.title
        bodyIn.text = n.body
    }

    title: "Quick notes"
    status: "note " + pad(Notes.current + 1) + " / " + pad(Notes.notes.length)

    Connections {
        target: Notes
        function onRevisionChanged() { root.load() }
        function onCurrentChanged() { root.load() }
    }
    Component.onCompleted: load()

    Item {
        id: head
        width: parent.width
        height: 30

        Mono {
            id: slashes
            text: "//"
            color: Theme.accent
            font.pixelSize: 22
            anchors.verticalCenter: parent.verticalCenter
        }
        TextInput {
            id: titleIn
            anchors { left: slashes.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
            font.family: Theme.mono
            font.pixelSize: 22
            color: Theme.text
            selectionColor: Theme.accentDim
            clip: true
            onTextEdited: Notes.update("title", text)
        }
    }

    TextEdit {
        id: bodyIn
        anchors { top: head.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: foot.top; bottomMargin: 12 }
        wrapMode: TextEdit.Wrap
        clip: true
        font.family: Theme.mono
        font.pixelSize: 15
        color: Theme.text
        selectionColor: Theme.accentDim
        onTextChanged: { if (activeFocus) Notes.update("body", text) }
    }

    Row {
        id: foot
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 8

        Btn {
            width: parent.width - addB.width - delB.width - 16
            label: "\u2193 Notes \u00B7 " + root.pad(Notes.notes.length)
            onClicked: Notes.next()
        }
        Btn { id: addB; label: "+ New"; onClicked: Notes.add() }
        Btn { id: delB; label: "Del"; onClicked: Notes.removeCurrent() }
    }
}
