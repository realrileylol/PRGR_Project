import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: card
    width: 210; height: 72
    radius: 8
    color: "#12171D"
    border.color: "#1C2733"

    property string label: "Metric"
    property string value: "--"

    Column {
        anchors.fill: parent; anchors.margins: 10; spacing: 4
        Label { text: label; color: "#9FB0C4"; font.pixelSize: 14 }
        Label { text: value; color: "white"; font.pixelSize: 22; font.bold: true }
    }
}
