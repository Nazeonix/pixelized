pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var notes: [{ title: "Before I leave", body: "Pick up groceries\nCharge the headphones\nBack up the dotfiles" }]
    property int current: 0
    property int revision: 0   // bumped on load/add/delete so editors reload their text

    function update(key, value) {
        notes[current][key] = value     // in place: typing must not rebind the editors
        saveTimer.restart()
    }
    function next() {
        current = (current + 1) % notes.length
    }
    function add() {
        notes = notes.concat([{ title: "New note", body: "" }])
        current = notes.length - 1
        revision++
        saveTimer.restart()
    }
    function removeCurrent() {
        if (notes.length <= 1) notes = [{ title: "", body: "" }]
        else notes = notes.filter((n, i) => i !== current)
        current = Math.min(current, notes.length - 1)
        revision++
        saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: file.setText(JSON.stringify(root.notes, null, 2))
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell/clover/notes.json"
        onLoaded: {
            try {
                const d = JSON.parse(text())
                if (Array.isArray(d) && d.length > 0) {
                    root.notes = d
                    root.current = 0
                    root.revision++
                }
            } catch (e) { }
        }
    }
}
