import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: launchSettings
    width: 480
    height: 800

    property real baseLaunchAngle: 16.0   // default estimated launch angle
    property real launchVariance: 2.0     // possible variation ±°

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
                text: "Launch Angle Settings"
                color: "#F0F6FC"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Set your baseline launch angle and how much variation you want the simulator to apply. A higher launch angle increases carry but can reduce roll."
            color: "#8B949E"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Baseline Launch Angle ---
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
                    text: "Baseline Launch Angle: " + baseLaunchAngle.toFixed(1) + "°"
                    color: "#F0F6FC"
                    font.pixelSize: 22
                    font.bold: true
                }

                Slider {
                    id: baseSlider
                    from: 8; to: 22; stepSize: 0.1
                    value: baseLaunchAngle
                    onValueChanged: baseLaunchAngle = value
                }

                Label {
                    text: {
                        if (baseLaunchAngle < 12) return "Low Launch – More Roll, Less Carry"
                        else if (baseLaunchAngle < 17) return "Mid Launch – Balanced Carry & Roll"
                        else return "High Launch – Max Carry, Less Roll"
                    }
                    color: "#A6D189"
                    font.pixelSize: 16
                }
            }
        }

        // --- Launch Variance ---
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
                    text: "Launch Variance: ±" + launchVariance.toFixed(1) + "°"
                    color: "#F0F6FC"
                    font.pixelSize: 22
                    font.bold: true
                }

                Slider {
                    id: varianceSlider
                    from: 0; to: 4; stepSize: 0.1
                    value: launchVariance
                    onValueChanged: launchVariance = value
                }

                Label {
                    text: "Higher variance makes results less consistent but more realistic."
                    color: "#8B949E"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
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
