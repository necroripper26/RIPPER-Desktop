import QtQuick
import QtMultimedia
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

WallpaperItem {
    id: root
    accentColor: "#D8D8D8"
    clip: true

    property var clock: new Date()
    property var stats: ({cpu:null,ram:null,gpu:null,disk:null,temp:null,uptime:null,
                          memoryText:"",diskText:"",ssid:"",down:null,up:null,
                          title:"",artist:"",status:"",progress:0})
    property bool portrait: height > width * 1.06
    property real unit: Math.max(0.66, Math.min(1.4, Math.min(width / 1600, height / 900)))
    property real margin: 34 * unit
    property real filmShare: Math.max(30, Math.min(48, Number(configuration.CenterWidth || 38))) / 100
    property real filmWidth: portrait ? width : width * filmShare
    property real filmLeft: (width - filmWidth) / 2
    property real panelWidth: Math.max(160, filmLeft - 2 * margin)
    property real panelAlpha: Math.max(0.35, Math.min(0.95, Number(configuration.PanelOpacity || 70) / 100))
    property color violet: "#D0D0D0"
    property color cyan: "#B3B3B3"
    property color whiteText: "#F4F4F4"
    property color muted: "#ACACAC"
    property string mono: "DejaVu Sans Mono"
    property string videoLocation: configuration.VideoEnabled === false ? "" : String(configuration.VideoPath || "")
    property url videoSource: makeUrl(videoLocation)

    function makeUrl(value) {
        var path = String(value || "").trim()
        if (path.length === 0) return ""
        if (path.indexOf("://") >= 0) return path
        if (path.charAt(0) === "/") return "file://" + path
        return Qt.resolvedUrl(path)
    }
    function two(n) { return (n < 10 ? "0" : "") + n }
    function percent(n) { return n === null || n === undefined || isNaN(Number(n)) ? -1 : Number(n) }
    function pctText(n) { return percent(n) < 0 ? "N/D" : Math.round(Number(n)) + "%" }
    function tempText(n) { return percent(n) < 0 ? "N/D" : Math.round(Number(n)) + "°C" }
    function upperDay(d) { return ["DOMINGO","LUNES","MARTES","MIÉRCOLES","JUEVES","VIERNES","SÁBADO"][d.getDay()] }
    function upperMonth(d) { return ["ENERO","FEBRERO","MARZO","ABRIL","MAYO","JUNIO","JULIO","AGOSTO","SEPTIEMBRE","OCTUBRE","NOVIEMBRE","DICIEMBRE"][d.getMonth()] }
    function monthStartOffset() {
        var d = new Date(clock.getFullYear(), clock.getMonth(), 1)
        return (d.getDay() + 6) % 7
    }
    function calendarDate(index) {
        var day = index - monthStartOffset() + 1
        var count = new Date(clock.getFullYear(), clock.getMonth() + 1, 0).getDate()
        return day >= 1 && day <= count ? String(day) : ""
    }
    function mediaAction(command) {
        if (["play-pause", "next", "previous"].indexOf(command) >= 0)
            controlSource.connectSource("playerctl " + command)
    }

    // Full-screen monochrome photograph. Never crop into a center strip.
    Rectangle { anchors.fill: parent; color: "#000000" }
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../images/crimson.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    // Only when explicitly enabled, a video appears in the middle.
    MediaPlayer {
        id: videoPlayer
        source: root.videoSource
        loops: MediaPlayer.Infinite
        videoOutput: movingVideo
        audioOutput: AudioOutput { muted: true }
        autoPlay: root.videoLocation.length > 0
        Component.onCompleted: {
            if (root.videoLocation.length > 0)
                Qt.callLater(function() { videoPlayer.play() })
        }
        onSourceChanged: {
            if (root.videoLocation.length > 0)
                Qt.callLater(function() { videoPlayer.play() })
        }
        onErrorOccurred: function(error, message) {
            console.warn("RIPPER_CRIMSON_VIDEO:", message)
        }
    }
    VideoOutput {
        id: movingVideo
        x: root.filmLeft; y: 0; width: root.filmWidth; height: root.height
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root.videoLocation.length > 0 && videoPlayer.playbackState === MediaPlayer.PlayingState
    }
    // Neutral borders only when central video is active.
    Repeater {
        model: root.portrait || !movingVideo.visible ? [] : [root.filmLeft, root.filmLeft + root.filmWidth]
        delegate: Rectangle {
            required property real modelData
            x: modelData - 1
            width: 2
            height: root.height
            color: "#B8B8B8"
            opacity: 0.62
        }
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.clock = new Date() }

    Plasma5Support.DataSource {
        id: statsSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            if (Number(data["exit code"]) === 0) {
                try { root.stats = JSON.parse(String(data["stdout"])) }
                catch (error) { console.warn("RIPPER_NOVA_STATS:", error) }
            }
            disconnectSource(sourceName)
        }
    }
    Plasma5Support.DataSource {
        id: controlSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            root.refreshStats()
        }
    }
    function refreshStats() { statsSource.connectSource("__STATS_COMMAND__") }
    Timer { interval: 9000; running: true; repeat: true; onTriggered: root.refreshStats() }
    Component.onCompleted: root.refreshStats()

    // ----------- LANDSCAPE EDITION: the 3-column reference layout -----------
    Item {
        id: landscape
        anchors.fill: parent
        visible: !root.portrait
        // Logo and motto, matching the left editorial column.
        Text {
            x: root.margin + 14 * root.unit; y: 59 * root.unit
            text: "CRIMSON"
            font.family: root.mono; font.bold: true
            font.pixelSize: 32 * root.unit
            color: root.violet
            style: Text.Outline; styleColor: "#1B1B1B"
        }
        Text {
            x: root.margin + 15 * root.unit; y: 97 * root.unit
            text: "GHOST  //  MONOCHROME EDITION"
            color: root.whiteText; font.family: root.mono
            font.pixelSize: 10 * root.unit; font.letterSpacing: 2
        }
        Text {
            x: root.margin + 15 * root.unit; y: 125 * root.unit
            text: "RIPPER  //  BLACK & WHITE"
            width: root.panelWidth - 25 * root.unit
            color: "#B3B3B3"; font.family: root.mono
            font.pixelSize: 8.7 * root.unit
            elide: Text.ElideRight
        }

        // Clock
        GlassCard {
            id: clockCard
            x: root.margin; y: 185 * root.unit
            width: root.panelWidth; height: 147 * root.unit
            scaleFactor: root.unit; alphaValue: root.panelAlpha
            Text {
                x: 20 * root.unit; y: 15 * root.unit
                text: root.two(root.clock.getHours()) + ":" + root.two(root.clock.getMinutes())
                color: root.whiteText
                font.family: root.mono; font.bold: true
                font.pixelSize: 50 * root.unit
            }
            Text {
                x: 20 * root.unit; y: 91 * root.unit
                text: root.upperDay(root.clock) + "  /  " + root.two(root.clock.getDate()) + " " + root.upperMonth(root.clock)
                width: parent.width - 32 * root.unit
                color: root.violet; font.family: root.mono
                font.bold: true; font.pixelSize: 13 * root.unit
                elide: Text.ElideRight
            }
            Rectangle { x: 20*root.unit; y: 122*root.unit; width: parent.width-40*root.unit; height: 1; color: "#444444" }
            Text {
                x: 20*root.unit; y: 127*root.unit
                text: "KDE PLASMA 6  //  WAYLAND  //  " + root.clock.getFullYear()
                color: root.muted; font.family: root.mono; font.pixelSize: 8*root.unit
            }
        }

        // Compact live hardware summary on the left.
        GlassCard {
            id: hardwareCard
            visible: configuration.ShowPerformance !== false
            x: root.margin; y: 350 * root.unit
            width: root.panelWidth; height: 243 * root.unit
            scaleFactor: root.unit; alphaValue: root.panelAlpha
            Text {
                x: 21*root.unit; y: 15*root.unit
                text: "◇  HARDWARE / LIVE"
                color: root.violet; font.bold: true
                font.family: root.mono; font.pixelSize: 12*root.unit
            }
            MeasureBar { x: 23*root.unit; y: 52*root.unit; width: parent.width-46*root.unit; caption: "CPU"; value: root.percent(root.stats.cpu); tint: root.violet; scaleFactor: root.unit }
            MeasureBar { x: 23*root.unit; y: 108*root.unit; width: parent.width-46*root.unit; caption: "RAM"; value: root.percent(root.stats.ram); tint: root.violet; scaleFactor: root.unit; extra: root.stats.memoryText || "" }
            MeasureBar { x: 23*root.unit; y: 164*root.unit; width: parent.width-46*root.unit; caption: "GPU"; value: root.percent(root.stats.gpu); tint: root.cyan; scaleFactor: root.unit }
            Text {
                x: 23*root.unit; y: 219*root.unit
                text: "CPU " + root.tempText(root.stats.temp) + "    UPTIME " + (root.stats.uptime === null ? "N/D" : root.stats.uptime + " h")
                color: root.muted; font.family: root.mono; font.pixelSize: 9*root.unit
            }
        }

        // Music panel: titles/status are real MPRIS/Playerctl values.
        GlassCard {
            id: musicCard
            visible: configuration.ShowMusic !== false
            x: root.margin; y: root.height - height - 60 * root.unit
            width: root.panelWidth; height: 205 * root.unit
            scaleFactor: root.unit; alphaValue: root.panelAlpha
            Text {
                x: 23*root.unit; y: 17*root.unit
                text: "♫  NOW PLAYING"
                color: root.violet; font.bold: true
                font.family: root.mono; font.pixelSize: 12*root.unit
            }
            // Animated equalizer: motion reflects playback status, not true audio amplitude.
            Item {
                id: eqVisualizer
                x: parent.width - 103*root.unit
                y: 14*root.unit
                width: 76*root.unit
                height: 24*root.unit
                property real phase: 0
                NumberAnimation on phase {
                    from: 0; to: Math.PI * 2
                    duration: 900
                    loops: Animation.Infinite
                    running: root.stats.status === "Playing"
                }
                Row {
                    anchors.bottom: parent.bottom
                    spacing: 2*root.unit
                    Repeater {
                        model: 15
                        delegate: Rectangle {
                            required property int index
                            width: 3*root.unit
                            radius: width/2
                            height: root.stats.status === "Playing"
                                ? (5 + 17*Math.abs(Math.sin(eqVisualizer.phase + index*0.77)))*root.unit
                                : 4*root.unit
                            color: index%3===0 ? "#FFFFFF" : "#A8A8A8"
                        }
                    }
                }
            }
            Text {
                x: parent.width-73*root.unit; y: 18*root.unit
                text: root.stats.status === "Playing" ? "● LIVE" : root.stats.status === "Paused" ? "Ⅱ PAUSA" : "SIN AUDIO"
                color: root.stats.status === "Playing" ? "#D0D0D0" : root.muted
                font.family: root.mono; font.pixelSize: 9*root.unit
            }
            Text {
                x: 23*root.unit; y: 58*root.unit
                width: parent.width - 46*root.unit
                text: root.stats.title || "Sin música reproduciéndose"
                color: root.whiteText; font.bold: true
                font.family: root.mono; font.pixelSize: 13*root.unit
                elide: Text.ElideRight
            }
            Text {
                x: 23*root.unit; y: 81*root.unit
                width: parent.width - 46*root.unit
                text: root.stats.artist || "MPRIS / PLAYERCTL"
                color: root.muted; font.family: root.mono
                font.pixelSize: 10*root.unit; elide: Text.ElideRight
            }
            Rectangle {
                x: 23*root.unit; y: 112*root.unit
                width: parent.width - 46*root.unit; height: 5*root.unit
                radius: height/2; color: "#3A3A3A"
                Rectangle {
                    width: parent.width * Math.max(0,Math.min(1,Number(root.stats.progress||0)))
                    height: parent.height; radius: height/2; color: root.violet
                }
            }
            Row {
                x: 23*root.unit; y: 130*root.unit; spacing: 14*root.unit
                Repeater {
                    model: [
                        {icon:"◀◀", cmd:"previous"},
                        {icon: root.stats.status === "Playing" ? "Ⅱ" : "▶", cmd:"play-pause"},
                        {icon:"▶▶", cmd:"next"}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 52*root.unit; height: 34*root.unit
                        radius: 8*root.unit
                        color: "#161616"; border.color: "#777777"
                        Text { anchors.centerIn: parent; text: modelData.icon; color: root.whiteText; font.pixelSize: 12*root.unit }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mediaAction(modelData.cmd) }
                    }
                }
            }
            Text {
                x: 23*root.unit; y: 178*root.unit
                text: "PLAYERCTL  //  CONTROLES ACTIVOS"
                color: "#AAAAAA"; font.family: root.mono; font.pixelSize: 8*root.unit
            }
        }

        // Right: detailed system telemetry.
        GlassCard {
            id: telemetryCard
            visible: configuration.ShowPerformance !== false
            x: root.width - width - root.margin
            y: 62*root.unit
            width: root.panelWidth; height: 318*root.unit
            scaleFactor: root.unit; alphaValue: root.panelAlpha
            Text {
                x: 22*root.unit; y: 17*root.unit
                text: "✧  SYSTEM MONITOR"
                color: root.violet; font.bold: true
                font.family: root.mono; font.pixelSize: 14*root.unit
            }
            Text {
                x: 22*root.unit; y: 45*root.unit
                text: "LIVE TELEMETRY / LOCAL HOST"
                color: root.muted; font.family: root.mono; font.pixelSize: 9*root.unit
            }
            MeasureBar { x: 25*root.unit; y: 83*root.unit; width: parent.width-50*root.unit; caption: "CPU"; value: root.percent(root.stats.cpu); tint: root.violet; scaleFactor: root.unit }
            MeasureBar { x: 25*root.unit; y: 140*root.unit; width: parent.width-50*root.unit; caption: "RAM"; value: root.percent(root.stats.ram); tint: root.violet; scaleFactor: root.unit; extra: root.stats.memoryText || "" }
            MeasureBar { x: 25*root.unit; y: 197*root.unit; width: parent.width-50*root.unit; caption: "GPU"; value: root.percent(root.stats.gpu); tint: root.cyan; scaleFactor: root.unit }
            MeasureBar { x: 25*root.unit; y: 254*root.unit; width: parent.width-50*root.unit; caption: "SSD"; value: root.percent(root.stats.disk); tint: root.violet; scaleFactor: root.unit; extra: root.stats.diskText || "" }
        }

        // Calendar, months and dates generated from actual system time.
        GlassCard {
            id: calendarCard
            visible: configuration.ShowCalendar !== false
            x: root.width - width - root.margin
            y: 400*root.unit
            width: root.panelWidth; height: 247*root.unit
            scaleFactor: root.unit; alphaValue: root.panelAlpha
            Text {
                x: 22*root.unit; y: 15*root.unit
                text: "▣  CALENDARIO"
                color: root.violet; font.bold: true
                font.family: root.mono; font.pixelSize: 13*root.unit
            }
            Text {
                x: 22*root.unit; y: 44*root.unit
                text: root.upperMonth(root.clock) + "  " + root.clock.getFullYear()
                color: root.whiteText; font.family: root.mono; font.pixelSize: 10*root.unit
            }
            Grid {
                x: 21*root.unit; y: 79*root.unit
                columns: 7; rowSpacing: 4*root.unit; columnSpacing: 3*root.unit
                Repeater {
                    model: ["L","M","X","J","V","S","D"]
                    delegate: Text {
                        required property string modelData
                        text: modelData; width: 32*root.unit; height: 17*root.unit
                        horizontalAlignment: Text.AlignHCenter
                        color: root.violet; font.family: root.mono; font.pixelSize: 11*root.unit
                    }
                }
                Repeater {
                    model: 42
                    delegate: Rectangle {
                        required property int index
                        property string dayLabel: root.calendarDate(index)
                        width: 32*root.unit; height: 19*root.unit; radius: 5*root.unit
                        color: Number(dayLabel) === root.clock.getDate() && dayLabel.length > 0 ? "#777777" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.dayLabel
                            color: parent.dayLabel === String(root.clock.getDate()) ? "#FFFFFF" : "#D0D0D0"
                            font.family: root.mono; font.pixelSize: 10*root.unit
                        }
                    }
                }
            }
            Text {
                x: Math.min(parent.width-144*root.unit, 283*root.unit)
                y: 95*root.unit
                visible: parent.width > 360*root.unit
                text: "ENFOQUE\nDISCIPLINA\nY CREATIVIDAD"
                color: "#B3B3B3"
                font.family: root.mono; font.pixelSize: 11*root.unit
                lineHeight: 1.65
            }
        }

        GlassCard {
            id: networkCard
            visible: configuration.ShowNetwork !== false
            x: root.width - width - root.margin
            y: root.height - height - 63*root.unit
            width: root.panelWidth; height: 164*root.unit
            scaleFactor: root.unit; alphaValue: root.panelAlpha
            Text {
                x: 22*root.unit; y: 14*root.unit
                text: "⌁  RED / CONECTIVIDAD"
                color: root.violet; font.family: root.mono
                font.pixelSize: 13*root.unit; font.bold: true
            }
            Text {
                x: 23*root.unit; y: 45*root.unit
                width: parent.width-46*root.unit
                text: root.stats.ssid || "CONEXIÓN LOCAL"
                color: root.whiteText; font.family: root.mono
                font.pixelSize: 11*root.unit; elide: Text.ElideRight
            }
            Text {
                x: 23*root.unit; y: 75*root.unit
                text: "↓  " + (root.stats.down === null ? "N/D" : root.stats.down + " Mbps")
                color: root.cyan; font.family: root.mono; font.pixelSize: 12*root.unit
            }
            Text {
                x: 23*root.unit; y: 102*root.unit
                text: "↑  " + (root.stats.up === null ? "N/D" : root.stats.up + " Mbps")
                color: root.violet; font.family: root.mono; font.pixelSize: 12*root.unit
            }
            Text {
                x: 23*root.unit; y: 140*root.unit
                text: "TRÁFICO ACTUAL · NO VELOCIDAD CONTRATADA"
                color: "#9A9A9A"; font.family: root.mono; font.pixelSize: 8*root.unit
                elide: Text.ElideRight; width: parent.width-46*root.unit
            }
        }
        Text {
            x: root.margin + 10*root.unit
            y: root.height - 27*root.unit
            text: "RIPPER  /  CRIMSON GHOST"
            color: root.violet
            font.family: root.mono; font.pixelSize: 9*root.unit; font.letterSpacing: 2
        }
        Text {
            x: root.width - root.margin - width
            y: root.height - 27*root.unit
            text: "MONOCHROME  //  SYSTEM"
            color: root.violet
            font.family: root.mono; font.pixelSize: 9*root.unit; font.letterSpacing: 2
        }
    }

    // ----------- PORTRAIT: minimal video with two readable overlays -----------
    Item {
        anchors.fill: parent
        visible: root.portrait
        GlassCard {
            x: 18*root.unit; y: 34*root.unit
            width: parent.width-36*root.unit; height: 108*root.unit
            scaleFactor: root.unit; alphaValue: 0.72
            Text { x: 16*root.unit; y: 9*root.unit; text: "CRIMSON GHOST"; color: root.violet; font.family: root.mono; font.bold: true; font.pixelSize: 14*root.unit }
            Text { x: 16*root.unit; y: 30*root.unit; text: root.two(root.clock.getHours())+":"+root.two(root.clock.getMinutes()); color: root.whiteText; font.family: root.mono; font.bold: true; font.pixelSize: 37*root.unit }
            Text { x: 17*root.unit; y: 83*root.unit; text: root.upperDay(root.clock)+" / "+root.two(root.clock.getDate())+" "+root.upperMonth(root.clock); color: root.violet; font.family: root.mono; font.pixelSize: 9*root.unit }
        }
        GlassCard {
            visible: configuration.ShowPerformance !== false
            x: 18*root.unit; y: root.height-height-45*root.unit
            width: parent.width-36*root.unit; height: 105*root.unit
            scaleFactor: root.unit; alphaValue: 0.72
            Text { x: 16*root.unit; y: 12*root.unit; text: "SYSTEM STATUS"; color: root.violet; font.family: root.mono; font.pixelSize: 11*root.unit }
            Text { x: 16*root.unit; y: 40*root.unit; text: "CPU "+root.pctText(root.stats.cpu)+"   RAM "+root.pctText(root.stats.ram); color: root.whiteText; font.family: root.mono; font.pixelSize: 12*root.unit }
            Text { x: 16*root.unit; y: 70*root.unit; text: "GPU "+root.pctText(root.stats.gpu)+"   SSD "+root.pctText(root.stats.disk); color: root.cyan; font.family: root.mono; font.pixelSize: 12*root.unit }
        }
    }
}
