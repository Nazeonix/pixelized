pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (org.freedesktop.Notifications).
// Toasts: NotifPopups.qml   History panel: NotifCenter.qml   Bell: Taskbar.qml
// Only one daemon can own the name, so stop mako / dunst / swaync first.
Singleton {
    id: root

    property bool dnd: false              // do not disturb: no toasts (critical still shows)
    property var popups: []               // notifications currently shown as toasts, newest first
    property var arrived: ({})            // id -> arrival time (ms)

    readonly property var list: Array.from(server.trackedNotifications.values).reverse()
    readonly property int count: server.trackedNotifications.values.length

    function hidePopup(n) { popups = popups.filter(x => x !== n) }
    function dismiss(n) { hidePopup(n); n.dismiss() }
    function clear() {
        popups = []
        Array.from(server.trackedNotifications.values).forEach(n => n.dismiss())
    }
    function invokeDefault(n) {
        const a = Array.from(n.actions).find(x => x.identifier === "default")
        if (a) a.invoke()
        dismiss(n)
    }

    function iconSrc(n) {
        const img = n.image
        if (img && img !== "") return img.startsWith("/") ? "file://" + img : img
        const ic = n.appIcon
        if (ic && ic !== "") return ic.startsWith("/") ? "file://" + ic : Quickshell.iconPath(ic, "dialog-information")
        return Quickshell.iconPath(n.desktopEntry || (n.appName || "").toLowerCase(), "dialog-information")
    }

    function ago(ms) {
        if (!ms) return ""
        const m = Math.floor((Date.now() - ms) / 60000)
        if (m < 1) return "NOW"
        if (m < 60) return m + "M"
        return Math.floor(m / 60) + "H"
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            root.arrived[n.id] = Date.now()
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n].concat(root.popups.filter(x => x !== n)).slice(0, 5)
        }
    }
}
