import QtQuick
import Quickshell

Panel {
    id: root
    title: "Time // local"
    status: Qt.formatDateTime(clk.date, "ddd d MMM")

    SystemClock { id: clk; precision: SystemClock.Minutes }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        Mono { text: Qt.formatDateTime(clk.date, "HH"); font.pixelSize: 46; font.weight: Font.Light }
        Mono { text: ":"; color: Theme.accent; font.pixelSize: 46; font.weight: Font.Light }
        Mono { text: Qt.formatDateTime(clk.date, "mm"); font.pixelSize: 46; font.weight: Font.Light }
    }
}
