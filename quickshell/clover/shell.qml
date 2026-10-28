import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: scr
            required property var modelData
            readonly property int ws: Hyprland.monitorFor(modelData)?.activeWorkspace?.id ?? 1

            Variants {
                model: Store.idsFor(scr.ws)
                delegate: WidgetWindow { screen: scr.modelData }
            }
            WallpaperLayer { screen: scr.modelData }
            EditOverlay { screen: scr.modelData; ws: scr.ws }
            Launcher { screen: scr.modelData }
            StartMenu { screen: scr.modelData }
            Taskbar { screen: scr.modelData }
            AltTab { screen: scr.modelData }
            NotifPopups { screen: scr.modelData }
            BatteryAlert { screen: scr.modelData }
            NotifCenter { screen: scr.modelData }

            VolumeOsdLayer { screen: scr.modelData }
            BrightnessOsdLayer { screen: scr.modelData }
            StatusOsdLayer { screen: scr.modelData }
        }
    }

    TitleBars {}
    Idle { id: idle }
    BatteryWatch {}
    SettingsApp {}

    IpcHandler {
        target: "wallpaper"
        function next(): void { Wallpaper.next() }
        function prev(): void { Wallpaper.prev() }
        function random(): void { Wallpaper.random() }
        function set(path: string): void { Wallpaper.set(path) }
        function auto(minutes: int): void { Wallpaper.autoMinutes = minutes; Wallpaper.save() }
    }

    IpcHandler {
        target: "clover"
        function edit(): void { Store.editing = !Store.editing }
        function hide(): void { Store.hidden = !Store.hidden }
        function toggle(type: string): void { Store.toggleType(type) }
        function dock(type: string, corner: string): void { Store.dock(type, corner) }
        function launcher(): void { Store.launcherOpen = !Store.launcherOpen }
        function settings(): void { Store.settingsOpen = !Store.settingsOpen }
        function titlebars(): void { Store.titlebars = !Store.titlebars }
        function start(): void { Store.startOpen = !Store.startOpen }
        function add(type: string): void { Store.add(type, Hyprland.focusedWorkspace?.id ?? 1) }
    }

    IpcHandler {
        target: "battery"
        function test(level: int): void {
            Store.batPct = level === 1 ? Settings.batLevel1 : (level === 2 ? Settings.batLevel2 : Settings.batLevel3)
            Store.batLevel = level
        }
    }

    IpcHandler {
        target: "idle"
        function toggle(): void { Settings.idleKeepAwake = !Settings.idleKeepAwake }
        function lock(): void { idle.lockNow() }
        function suspend(): void { idle.suspendNow() }
        function dimtest(): void { idle.dimTest() }
    }

    IpcHandler {
        target: "notify"
        function center(): void { Store.notifCenter = !Store.notifCenter }
        function dnd(): void { Notifs.dnd = !Notifs.dnd }
        function clear(): void { Notifs.clear() }
    }

    IpcHandler {
        target: "alttab"
        function next(): void { Store.altStep(1) }
        function prev(): void { Store.altStep(-1) }
        function commit(): void { Store.altCommit() }
        function cancel(): void { Store.altCancel() }
    }

    IpcHandler {
        target: "volume"
        function show(): void {
            const a = Pipewire.defaultAudioSink?.audio
            if (a) VolumeOsd.flash(a.volume, a.muted)
        }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { BrightnessOsd.step("5%+") }
        function down(): void { BrightnessOsd.step("5%-") }
        function read(): void { BrightnessOsd.read() }
    }
}
