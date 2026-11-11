import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

WallpaperItem {
    id: root
    accentColor: "#d52635"
    property date clock: new Date()
    property var stats: ({cpu: null, ram: null, gpu: null, disk: null,
                           temp: null, uptime: null, artist:"", title:"", status:"", progress:0})
    property bool portrait: height > width * 1.16
    property bool narrow: width < 1000 || portrait
    property real scaleUnit: Math.max(0.70, Math.min(1.35, width / 1536))
    property color ink: "#151515"
    property color red: "#d52635"
    property color muted: "#4d4747"
    property string fontFamily: "DejaVu Sans Mono"

    function fmt(v, suffix) {
        return v === null || v === undefined || v === "" ? "N/D" : String(v) + (suffix || "")
    }
    function pct(v) {
        return v === null || v === undefined || isNaN(Number(v)) ? 0 :
               Math.max(0, Math.min(100, Number(v)))
    }
    function upperDay(d) {
        var days = ["DOMINGO", "LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO"]
        return days[d.getDay()]
    }
    function upperMonth(d) {
        var months = ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]
        return months[d.getMonth()]
    }
    function digits(n) { return String(n).padStart(2, "0") }

    Rectangle { anchors.fill: parent; color: "#efedeb" }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../images/ritual-art.png")
        fillMode: root.portrait ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: true
    }

    // Transparent gentle paper overlays preserve the readable typographic columns.
    Rectangle {
        x: 0; y: 0; width: root.portrait ? parent.width : parent.width * 0.265
        height: root.portrait ? Math.min(parent.height * 0.31, 345) : parent.height
        color: "#b9efedeb"
    }
    Rectangle {
        visible: !root.portrait
        x: parent.width * 0.79; y: 0; width: parent.width * 0.21; height: parent.height
        color: "#b8efedeb"
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.clock = new Date()
    }

    Plasma5Support.DataSource {
        id: statsSource
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            if (Number(data["exit code"]) === 0) {
                try { root.stats = JSON.parse(String(data["stdout"])) }
                catch (e) { console.warn("RIPPER stats parse:", e) }
            }
            disconnectSource(sourceName)
        }
    }
    function refreshStats() { statsSource.connectSource("__STATS_COMMAND__") }
    Timer { interval: 7500; repeat: true; running: true; onTriggered: root.refreshStats() }
    Component.onCompleted: root.refreshStats()

    Item {
        id: clockPanel
        x: Math.max(18, root.width * 0.022)
        y: root.portrait ? 42 : Math.max(28, root.height * 0.075)
        width: root.portrait ? root.width - 36 : Math.min(440, root.width * 0.29)
        height: Math.min(330, root.height * 0.37)

        Text {
            x: 0; y: 0
            text: root.upperDay(root.clock)
            font.family: root.fontFamily; font.bold: true
            font.pixelSize: Math.min(root.portrait ? 39 : 49 * root.scaleUnit, root.width * 0.095)
            font.letterSpacing: -2; color: root.ink
        }
        Text {
            x: 0; y: 58 * root.scaleUnit
            text: root.digits(root.clock.getDate())
            font.family: root.fontFamily; font.bold: true
            font.pixelSize: 61 * root.scaleUnit; color: root.red
        }
        Text {
            x: 0; y: 122 * root.scaleUnit
            text: root.upperMonth(root.clock)
            font.family: root.fontFamily; font.bold: true
            font.pixelSize: Math.min(46 * root.scaleUnit, root.width * 0.076)
            font.letterSpacing: -2; color: root.ink
        }
        Text {
            x: 0; y: 185 * root.scaleUnit
            text: root.digits(root.clock.getHours()) + ":" + root.digits(root.clock.getMinutes())
            font.family: root.fontFamily; font.bold: true
            font.pixelSize: 49 * root.scaleUnit; color: root.red
        }
        Text {
            x: 212 * root.scaleUnit; y: 213 * root.scaleUnit
            text: root.digits(root.clock.getSeconds())
            font.family: root.fontFamily; font.bold: true
            font.pixelSize: 23 * root.scaleUnit; color: root.ink
        }
        Rectangle { x: 0; y: 254 * root.scaleUnit; width: Math.min(parent.width, 310 * root.scaleUnit); height: 2; color: root.red }
        Text {
            x: 0; y: 265 * root.scaleUnit
            text: "RIPPER // " + root.clock.getFullYear() + "." + root.digits(root.clock.getMonth()+1) + "." + root.digits(root.clock.getDate())
            color: root.muted; font.family: root.fontFamily; font.pixelSize: 11 * root.scaleUnit
        }
    }

    Item {
        id: musicPanel
        x: Math.max(20, root.width * 0.023)
        width: root.portrait ? root.width - 40 : Math.min(420, root.width * 0.29)
        height: 174 * root.scaleUnit
        y: root.portrait ? root.height - (495 * root.scaleUnit) : root.height - (210 * root.scaleUnit)
        Text {
            text: "[MUSIC] // NOW PLAYING"
            color: root.red
            font.family: root.fontFamily; font.bold: true
            font.pixelSize: 13 * root.scaleUnit
        }
        Text {
            y: 29 * root.scaleUnit
            text: root.stats.status === "Playing" ? "[PLAYING]" : root.stats.status === "Paused" ? "[PAUSED]" : "[SIN REPRODUCCIÓN]"
            color: root.ink; font.family: root.fontFamily; font.pixelSize: 11 * root.scaleUnit
        }
        Text {
            y: 57 * root.scaleUnit
            width: parent.width
            text: root.stats.artist ? String(root.stats.artist) : "RIPPER AUDIO"
            elide: Text.ElideRight; color: root.muted
            font.family: root.fontFamily; font.bold: true; font.pixelSize: 11 * root.scaleUnit
        }
        Text {
            y: 78 * root.scaleUnit
            width: parent.width
            text: root.stats.title ? String(root.stats.title) : "PLAYERCTL / MPRIS"
            elide: Text.ElideRight; color: root.ink
            font.family: root.fontFamily; font.pixelSize: 12 * root.scaleUnit
        }
        Rectangle {
            y: 106 * root.scaleUnit
            width: parent.width; height: 6 * root.scaleUnit; color: "#8d8585"
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Number(root.stats.progress || 0)))
                height: parent.height; color: root.red
            }
        }
        Text {
            y: 122 * root.scaleUnit
            text: "[◀]  [Ⅱ]  [▶]    // AUDIO CONTROL: PLAYERCTL"
            font.family: root.fontFamily; color: root.muted; font.pixelSize: 9 * root.scaleUnit
        }
        Rectangle { y: 149 * root.scaleUnit; width: parent.width; height: 1; color: "#777777" }
    }

    Item {
        id: systemPanel
        x: root.portrait ? 22 : root.width - width - Math.max(20, root.width * 0.025)
        y: root.portrait ? root.height - 265 * root.scaleUnit : root.height * 0.52
        width: root.portrait ? root.width - 44 : Math.min(288, root.width * 0.187)
        height: 280 * root.scaleUnit
        Text {
            x: 0; y: 0
            text: "RIPPER // SYSTEM"
            color: root.red
            font.family: root.fontFamily; font.bold: true; font.pixelSize: 13 * root.scaleUnit
        }
        Rectangle { x: 0; y: 28 * root.scaleUnit; width: parent.width; height: 1; color: root.red }
        Repeater {
            model: [
                {key:"CPU", value: root.stats.cpu},
                {key:"RAM", value: root.stats.ram},
                {key:"GPU", value: root.stats.gpu},
                {key:"DISCO", value: root.stats.disk}
            ]
            delegate: Item {
                required property var modelData
                required property int index
                x: 0; y: (41 + index * 43) * root.scaleUnit
                width: systemPanel.width; height: 36 * root.scaleUnit
                Text {
                    x: 0; y: 0; text: modelData.key
                    color: root.ink; font.family: root.fontFamily
                    font.pixelSize: 11 * root.scaleUnit
                }
                Rectangle {
                    x: systemPanel.width * 0.35; y: 3 * root.scaleUnit
                    width: systemPanel.width * 0.43; height: 9 * root.scaleUnit
                    color: "#c1bdbd"; border.width: 1; border.color: "#5b5555"
                    Rectangle {
                        height: parent.height; color: root.ink
                        width: parent.width * root.pct(modelData.value) / 100
                    }
                }
                Text {
                    x: systemPanel.width * 0.8; y: 0
                    width: systemPanel.width * 0.2
                    horizontalAlignment: Text.AlignRight
                    text: root.fmt(modelData.value, "%")
                    color: root.ink; font.family: root.fontFamily; font.pixelSize: 10 * root.scaleUnit
                }
            }
        }
        Rectangle { x: 0; y: 218 * root.scaleUnit; width: parent.width; height: 1; color: root.red }
        Text {
            x: 0; y: 230 * root.scaleUnit
            text: "TEMP CPU " + root.fmt(root.stats.temp, "°C")
            color: root.muted; font.family: root.fontFamily; font.pixelSize: 11 * root.scaleUnit
        }
        Text {
            x: 0; y: 253 * root.scaleUnit
            text: "UPTIME   " + root.fmt(root.stats.uptime, " h")
            color: root.muted; font.family: root.fontFamily; font.pixelSize: 11 * root.scaleUnit
        }
    }
}
