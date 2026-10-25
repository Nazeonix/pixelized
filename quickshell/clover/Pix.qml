import QtQuick

// Pixel-art bitmap: rows of chars. "." = empty, "#" = tone, "+" = tone2, any char found in palette uses that color.
Canvas {
    property var rows: []
    property color tone: Theme.text
    property color tone2: Theme.accent
    property var palette: ({})
    property int px: 2

    width: rows.length > 0 ? rows[0].length * px : 0
    height: rows.length * px

    onRowsChanged: requestPaint()
    onToneChanged: requestPaint()
    onTone2Changed: requestPaint()
    onPaletteChanged: requestPaint()
    onPxChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.clearRect(0, 0, width, height)
        for (let y = 0; y < rows.length; y++)
            for (let x = 0; x < rows[y].length; x++) {
                const ch = rows[y][x]
                if (ch === ".") continue
                const pc = palette[ch]
                c.fillStyle = pc !== undefined ? pc : (ch === "+" ? tone2 : tone)
                c.fillRect(x * px, y * px, px, px)
            }
    }
}
