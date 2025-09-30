import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: ballSettings
    width: 480
    height: 800

    property string ballCompression: "Mid (80–90)"
    property string ballBehavior: "Tour / Balanced"

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
                text: "Ball Settings"
                color: "#F0F6FC"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Choose your ball type and compression to simulate real-world performance differences. Softer balls compress more easily and reduce spin, while firmer balls launch higher with more spin."
            color: "#8B949E"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Compression Selection ---
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
                    text: "Compression Level:"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                ComboBox {
                    id: compressionSelect
                    Layout.fillWidth: true
                    model: [
                        "Low (<70) – Soft / High Launch / Low Spin",
                        "Mid (80–90) – Balanced / Tour-Like",
                        "High (90+) – Firm / High Spin / Lower Launch",
                        "Range / Distance – Very Firm / Lower Spin / Max Distance"
                    ]
                    currentIndex: 1
                    onCurrentTextChanged: ballCompression = currentText
                }
            }
        }

        // --- Behavior Focus ---
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
                    text: "Ball Behavior Focus:"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                ComboBox {
                    id: behaviorSelect
                    Layout.fillWidth: true
                    model: [
                        "Tour / Balanced",
                        "Spin Control (Greenside)",
                        "Low Spin (Distance Focused)",
                        "High Launch (Forgiveness)"
                    ]
                    currentIndex: 0
                    onCurrentTextChanged: ballBehavior = currentText
                }
            }
        }

        // --- Info Display ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#10151C"
            border.color: "#30363D"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8

                Label {
                    text: "Selected: " + ballCompression
                    color: "#A6D189"
                    font.pixelSize: 16
                }
                Label {
                    text: "Focus: " + ballBehavior
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
