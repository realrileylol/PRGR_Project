import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: tempSettings
    width: 480
    height: 800

    property real temperature: 72.0  // default simulation temp

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
                text: "Temperature Settings"
                color: "#F0F6FC"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Adjust temperature to simulate real-world ball flight conditions. Temperature affects air density, launch, and carry."
            color: "#8B949E"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Temperature Slider ---
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
                    text: "Temperature: " + temperature.toFixed(1) + " °F"
                    color: "#F0F6FC"
                    font.pixelSize: 22
                    font.bold: true
                }

                Slider {
                    id: tempSlider
                    from: 32; to: 105; stepSize: 0.5
                    value: temperature
                    onValueChanged: temperature = value
                }

                Label {
                    text: {
                        if (temperature < 50) return "Cold (Lower Carry)"
                        else if (temperature < 80) return "Mild (Neutral)"
                        else return "Hot (Slightly More Carry)"
                    }
                    color: "#A6D189"
                    font.pixelSize: 16
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
