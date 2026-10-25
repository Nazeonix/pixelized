pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Wallpaper daemon state: library folder, current image, auto-rotate.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/Pictures/Wallpapers"
    readonly property int count: lib.count

    property string current: ""
    property int autoMinutes: 0

    function save() { saveTimer.restart() }
    function set(path) {
        if (!path) return
        current = path
        save()
    }
    function indexOfCurrent() {
        for (let i = 0; i < lib.count; i++)
            if (lib.get(i, "filePath") === current) return i
        return -1
    }
    function step(d) {
        const n = lib.count
        if (n === 0) return
        const i = indexOfCurrent()
        set(lib.get(i < 0 ? 0 : (i + d + n) % n, "filePath"))
    }
    function next() { step(1) }
    function prev() { step(-1) }
    function random() {
        const n = lib.count
        if (n === 0) return
        let i = Math.floor(Math.random() * n)
        if (n > 1 && lib.get(i, "filePath") === current) i = (i + 1) % n
        set(lib.get(i, "filePath"))
    }

    // drag & drop: copy images into the library, then show the first one
    function addUrls(urls) {
        const paths = []
        for (let i = 0; i < urls.length; i++) {
            const p = decodeURIComponent(String(urls[i]).replace(/^file:\/\//, ""))
            if (/\.(png|jpe?g|webp|bmp|gif)$/i.test(p)) paths.push(p)
        }
        if (paths.length === 0) return
        copier.target = root.dir + "/" + paths[0].split("/").pop()
        copier.command = ["cp", "-n", "--"].concat(paths).concat([root.dir])
        copier.running = true
    }

    Process {
        id: copier
        property string target: ""
        onExited: root.set(target)
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: lib.folder = "file://" + root.dir
    }

    FolderListModel {
        id: lib
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: {
            if (root.current === "" && count > 0) root.current = get(0, "filePath")
        }
    }

    Timer {
        interval: Math.max(1, root.autoMinutes) * 60000
        running: root.autoMinutes > 0
        repeat: true
        onTriggered: root.random()
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: stateFile.setText(JSON.stringify({ current: root.current, auto: root.autoMinutes }, null, 2))
    }

    FileView {
        id: stateFile
        path: root.home + "/.config/quickshell/clover/wallpaper.json"
        onLoaded: {
            try {
                const d = JSON.parse(text())
                if (d.current) root.current = d.current
                root.autoMinutes = d.auto || 0
            } catch (e) { }
        }
    }
}
