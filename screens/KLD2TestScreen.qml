import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: kld2TestScreen
    width: 800
    height: 480

    property var win

    // Theme colors
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color success: "#34C759"
    readonly property color danger: "#DA3633"

    Rectangle {
        anchors.fill: parent
        color: bg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: "Back"
                    implicitWidth: 100
                    implicitHeight: 48
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#2D9A4F" : success
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        soundManager.playClick()
                        if (kld2Manager.is_running) {
                            kld2Manager.stop()
                        }
                        stack.goBack()
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "K-LD2 Radar Monitor"
                    color: text
                    font.pixelSize: 24
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Status indicator
                Rectangle {
                    width: 120
                    height: 48
                    radius: 6
                    color: kld2Manager.is_running ? success : edge

                    Text {
                        anchors.centerIn: parent
                        text: kld2Manager.is_running ? "● ACTIVE" : "○ STOPPED"
                        color: kld2Manager.is_running ? "white" : hint
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            // Main speed display
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 280
                radius: 12
                color: card
                border.color: edge
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    // Large speed display
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: currentSpeedText.text === "---" ? bg : "#E8F5E9"
                        border.color: currentSpeedText.text === "---" ? edge : success
                        border.width: 3

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                id: currentSpeedText
                                text: "---"
                                font.pixelSize: 96
                                font.bold: true
                                color: text
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "mph"
                                font.pixelSize: 24
                                color: hint
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                id: directionText
                                text: ""
                                font.pixelSize: 14
                                color: hint
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                }
            }

            // Info section
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Connection Status
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 8
                    color: bg

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: "Status"
                            font.pixelSize: 11
                            color: hint
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            id: connectionStatusText
                            text: "Not Connected"
                            font.pixelSize: 14
                            color: danger
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Peak Speed
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 8
                    color: bg

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: "Peak"
                            font.pixelSize: 11
                            color: hint
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            id: peakSpeedText
                            text: "---"
                            font.pixelSize: 14
                            color: accent
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Trigger Threshold
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 8
                    color: bg

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: "Threshold"
                            font.pixelSize: 11
                            color: hint
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "≥ 15 mph"
                            font.pixelSize: 14
                            color: text
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // Control buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Button {
                    text: kld2Manager.is_running ? "Stop Radar" : "Start Radar"
                    Layout.fillWidth: true
                    implicitHeight: 60
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: kld2Manager.is_running
                            ? (parent.pressed ? "#B02A27" : danger)
                            : (parent.pressed ? "#2D9A4F" : success)
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        soundManager.playClick()
                        if (kld2Manager.is_running) {
                            kld2Manager.stop()
                            currentSpeedText.text = "---"
                        } else {
                            kld2Manager.start()
                        }
                    }
                }

                Button {
                    text: "Reset Peak"
                    Layout.preferredWidth: 150
                    implicitHeight: 60
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#2563EB" : accent
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        soundManager.playClick()
                        peakSpeedText.text = "---"
                    }
                }
            }

            // Instructions
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: 8
                color: "#FFF9E6"
                border.color: "#FFD700"
                border.width: 2

                Text {
                    anchors.fill: parent
                    anchors.margins: 15
                    text: "💡 Setup: Place radar 2-4 feet behind ball, pointing at ball. Radar detects RECEDING speeds only (ball moving away after impact). Ignores backswing/downswing."
                    font.pixelSize: 13
                    color: "#B8860B"
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Connections to K-LD2 Manager
    Connections {
        target: kld2Manager

        function onSpeedUpdated(speedMph) {
            // Update current speed display
            currentSpeedText.text = Math.round(speedMph).toString()

            // Update peak speed
            var currentPeak = peakSpeedText.text === "---" ? 0 : parseInt(peakSpeedText.text)
            if (speedMph > currentPeak) {
                peakSpeedText.text = Math.round(speedMph).toString()
            }

            // Flash the display briefly
            flashAnimation.restart()
        }

        function onStatusChanged(message, color) {
            connectionStatusText.text = message
            connectionStatusText.color = (color === "green" ? success :
                                         color === "red" ? danger : hint)
        }
    }

    // Flash animation for speed updates
    SequentialAnimation {
        id: flashAnimation
        NumberAnimation {
            target: currentSpeedText
            property: "scale"
            to: 1.1
            duration: 100
        }
        NumberAnimation {
            target: currentSpeedText
            property: "scale"
            to: 1.0
            duration: 100
        }
    }

    // Auto-start radar when screen loads
    Component.onCompleted: {
        if (!kld2Manager.is_running) {
            kld2Manager.start()
        }
    }
}
