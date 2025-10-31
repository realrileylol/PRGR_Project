import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: cameraScreen
    width: 800
    height: 480

    property var win
    property bool cameraActive: false

    // Theme colors matching MyBag.qml
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color cardHover: "#F9FAFB"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color success: "#34C759"
    readonly property color danger: "#DA3633"

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "← Back"
                implicitWidth: 100
                implicitHeight: 48

                background: Rectangle {
                    color: parent.pressed ? "#2D9A4F" : success
                    radius: 8
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
                    if (cameraActive) {
                        cameraManager.stopCamera()
                        cameraActive = false
                    }
                    stack.goBack()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Camera View"
                color: text
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Item { implicitWidth: 100; implicitHeight: 48 }
        }

        // Camera View Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#000000"
            border.color: edge
            border.width: 2

            // Camera preview placeholder
            Item {
                id: cameraContainer
                anchors.fill: parent
                anchors.margins: 2

                // Message when camera is not active
                Rectangle {
                    anchors.centerIn: parent
                    width: messageText.width + 40
                    height: messageText.height + 40
                    color: "#000000"
                    opacity: 0.8
                    radius: 12
                    visible: !cameraActive

                    Label {
                        id: messageText
                        anchors.centerIn: parent
                        text: "Click 'Start Camera' to begin live preview"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                // Status when camera is active
                Label {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 15
                    text: "● LIVE"
                    color: success
                    font.pixelSize: 16
                    font.bold: true
                    visible: cameraActive
                    background: Rectangle {
                        color: "#000000"
                        opacity: 0.7
                        radius: 6
                    }
                    padding: 10
                }
            }
        }

        // Camera Controls
        Rectangle {
            Layout.fillWidth: true
            height: 80
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20

                // Status indicator
                ColumnLayout {
                    spacing: 8

                    Label {
                        text: "Camera Status:"
                        color: text
                        font.pixelSize: 14
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: cameraActive ? success : danger
                        }

                        Label {
                            text: cameraActive ? "Active" : "Stopped"
                            color: hint
                            font.pixelSize: 14
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Control buttons
                Button {
                    text: cameraActive ? "Stop Camera" : "Start Camera"
                    implicitHeight: 50
                    implicitWidth: 150

                    background: Rectangle {
                        color: parent.pressed ? "#2563EB" : accent
                        radius: 8
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
                        if (cameraActive) {
                            cameraManager.stopCamera()
                            cameraActive = false
                        } else {
                            cameraManager.startCamera()
                            cameraActive = true
                        }
                    }
                }
            }
        }

        // Info text
        Label {
            Layout.fillWidth: true
            text: "Note: Camera preview opens in a centered window (480x360) on your screen."
            color: hint
            font.pixelSize: 12
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component.onDestruction: {
        if (cameraActive) {
            cameraManager.stopCamera()
        }
    }
}
