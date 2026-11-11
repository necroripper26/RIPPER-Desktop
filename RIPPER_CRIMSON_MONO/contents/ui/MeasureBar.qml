import QtQuick

Item {
    id: control
    property string caption: "CPU"
    property real value: -1
    property string suffix: "%"
    property color tint: "#D8D8D8"
    property real scaleFactor: 1
    property string extra: ""
    width: 200 * scaleFactor
    height: 51 * scaleFactor

    Text {
        x: 0; y: 0
        text: control.caption
        color: "#EFEFEF"
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 12 * control.scaleFactor
        font.bold: true
    }
    Text {
        anchors.right: parent.right
        y: 0
        text: control.value < 0 ? "N/D" : String(Math.round(control.value)) + control.suffix
        color: control.tint
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 12 * control.scaleFactor
    }
    Rectangle {
        x: 0; y: 25 * control.scaleFactor
        width: parent.width; height: 7 * control.scaleFactor
        radius: 4 * control.scaleFactor
        color: "#353535"
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, control.value)) / 100
            height: parent.height
            radius: parent.radius
            color: control.tint
        }
    }
    Text {
        visible: control.extra.length > 0
        x: 0; y: 36 * control.scaleFactor
        text: control.extra
        color: "#AFAFAF"
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 9 * control.scaleFactor
    }
}
