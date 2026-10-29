pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi and Bluetooth state for the taskbar icons (NetworkManager + BlueZ command line tools).
Singleton {
    id: root

    property bool wifiOn: false
    property string ssid: ""
    property int signal: 0              // 0..100
    property bool secure: false         // connected network uses a password
    property bool btOn: false
    property int btConnected: 0

    // -1 radio off, 0 not connected, 1..4 signal strength
    readonly property int wifiLevel: !wifiOn ? -1 : (ssid === "" ? 0 : (signal >= 75 ? 4 : (signal >= 50 ? 3 : (signal >= 25 ? 2 : 1))))

    function refresh() {
        wifiProc.running = false
        wifiProc.running = true
        btProc.running = false
        btProc.running = true
    }
    function toggleWifi() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiOn ? "off" : "on"])
        wifiOn = !wifiOn
        soon.restart()
    }
    function toggleBt() {
        Quickshell.execDetached(["bluetoothctl", "power", btOn ? "off" : "on"])
        btOn = !btOn
        soon.restart()
    }

    Timer { id: soon; interval: 1200; onTriggered: root.refresh() }
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Process {
        id: wifiProc
        command: ["sh", "-c", "echo radio=$(nmcli radio wifi 2>/dev/null); nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null | grep '^yes' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let on = false, ssid = "", sig = 0, sec = false
                text.split("\n").forEach(l => {
                    if (l.indexOf("radio=") === 0) on = l.substring(6).trim() === "enabled"
                    else if (l.indexOf("yes:") === 0) {
                        const p = l.split(":")
                        sig = parseInt(p[1]) || 0
                        sec = p[2] !== "" && p[2] !== "--"
                        ssid = p.slice(3).join(":")
                    }
                })
                root.wifiOn = on
                root.ssid = ssid
                root.signal = sig
                root.secure = sec
            }
        }
    }
    Process {
        id: btProc
        command: ["sh", "-c", "echo on=$(bluetoothctl show 2>/dev/null | grep -i 'Powered:' | awk '{print $2}'); echo conn=$(bluetoothctl devices Connected 2>/dev/null | wc -l)"]
        stdout: StdioCollector {
            onStreamFinished: {
                text.split("\n").forEach(l => {
                    if (l.indexOf("on=") === 0) root.btOn = l.substring(3).trim() === "yes"
                    else if (l.indexOf("conn=") === 0) root.btConnected = parseInt(l.substring(5)) || 0
                })
            }
        }
    }
    // react quickly when NetworkManager reports a change
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: data => soon.restart() }
    }
}
