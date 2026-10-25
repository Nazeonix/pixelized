pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property real value: 0
    property bool muted: false
    property bool open: false
    property bool armed: false

    function flash(v, mute) {
        value = Math.max(0, Math.min(1, v))
        muted = !!mute
        open = true
        hide.restart()
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() {
            const a = Pipewire.defaultAudioSink.audio
            if (!root.armed) return
            root.flash(a.volume, a.muted)
        }
        function onMutedChanged() {
            const a = Pipewire.defaultAudioSink.audio
            if (!root.armed) return
            root.flash(a.volume, a.muted)
        }
    }

    Timer { running: true; interval: 1500; onTriggered: root.armed = true }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.open = false
    }
}
