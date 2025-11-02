import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: card
    width: 210; height: 72
    radius: 8
    color: "#FFFFFF"
    border.color: "#D0D5DD"
    border.width: 2

    property string label: "Metric"
    property string value: "--"

    Column {
        anchors.fill: parent; anchors.margins: 10; spacing: 4
        Label { text: label; color: "#5F6B7A"; font.pixelSize: 14 }
        Label { text: value; color: "#1A1D23"; font.pixelSize: 22; font.bold: true }
    }
}
