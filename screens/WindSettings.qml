import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: windSettings
    width: 480
    height: 800

    property real windSpeed: 10.0
    property real windDirection: 0.0   // -180 = headwind, 180 = tailwind

    Rectangle { anchors.fill: parent; color: "#0D1117" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Button {
                text: "← Back"
                background: Rectangle { color: "#238636"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16 }
                onClicked: stack.goBack()
            }
            Label {
                text: "Wind Settings"
                color: "#F0F6FC"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Adjust wind conditions to simulate real-world effects on carry distance."
            color: "#8B949E"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Wind Speed ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8

                Label {
                    text: "Wind Speed: " + windSpeed.toFixed(1) + " mph"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                Slider {
                    id: speedSlider
                    from: 0; to: 30; stepSize: 0.5
                    value: windSpeed
                    onValueChanged: windSpeed = value
                }
            }
        }

        // --- Wind Direction ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8

                Label {
                    text: "Wind Direction: " +
                          (windDirection < 0 ? "Headwind " : windDirection > 0 ? "Tailwind " : "Neutral ") +
                          "(" + windDirection.toFixed(0) + "°)"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                Slider {
                    id: directionSlider
                    from: -180; to: 180; stepSize: 5
                    value: windDirection
                    onValueChanged: windDirection = value
                }
            }
        }

        // --- Buttons ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Button {
                text: "Save & Return"
                Layout.fillWidth: true
                background: Rectangle { color: "#238636"; radius: 8 }
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 18; font.bold: true }
                onClicked: stack.goBack()
            }

            Button {
                text: "Save & Home"
                Layout.fillWidth: true
                background: Rectangle { color: "#1F6FEB"; radius: 8 }
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 18; font.bold: true }
                onClicked: {
                    stack.pop(null)
                    stack.pop(null)
                }
            }
        }
    }
}
--------------