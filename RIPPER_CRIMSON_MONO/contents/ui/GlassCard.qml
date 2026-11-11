import QtQuick

Rectangle {
    id: card
    property real scaleFactor: 1.0
    property real alphaValue: 0.76
    radius: 14 * scaleFactor
    color: Qt.rgba(0.018, 0.018, 0.018, alphaValue)
    border.width: 1
    border.color: Qt.rgba(0.8, 0.8, 0.8, 0.42)
    clip: true

    Rectangle {
        x: 0; y: 0
        width: parent.width; height: 2 * card.scaleFactor
        color: "#CACACA"
        opacity: 0.45
    }
    Rectangle {
        x: 0; y: 11 * card.scaleFactor
        width: 3 * card.scaleFactor; height: 22 * card.scaleFactor
        radius: 2 * card.scaleFactor
        color: "#E0E0E0"
    }
}
