import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: strip
    color: "#FFFFFF"; radius: 10; height: 76
    border.color: "#D0D5DD"
    border.width: 2

    property string clubName: "7 Iron"
    property real   loftDeg: 32.0
    property string ballType: "Mid-High (80–90)"
    property real   launchDeg: 16.2
    property bool   launchMeasured: false

    RowLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 12
        Column {
            spacing: 4
            Label { text: "Club: " + strip.clubName; color: "#1A1D23" }
            Label { text: "Ball: " + strip.ballType; color: "#1A1D23" }
        }
        Item { width: 12 }
        Column {
            spacing: 4
            Label { text: "Loft: " + strip.loftDeg.toFixed(1) + "°"; color: "#1A1D23" }
            Label {
                text: strip.launchMeasured
                      ? ("Launch: " + strip.launchDeg.toFixed(1) + "°")
                      : ("Launch: " + strip.launchDeg.toFixed(1) + "° *")
                color: strip.launchMeasured ? "#1A1D23" : "#3A86FF"
                font.italic: !strip.launchMeasured
            }
        }
    }
}
