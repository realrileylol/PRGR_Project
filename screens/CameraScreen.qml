import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 5.15

Item {
    id: cameraScreen
    width: 800
    height: 480

    property var win

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
                    camera.stop()
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

        // Camera View
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#000000"
            border.color: edge
            border.width: 2

            Camera {
                id: camera
                captureMode: Camera.CaptureViewfinder

                Component.onCompleted: {
                    camera.start()
                }
            }

            VideoOutput {
                id: videoOutput
                source: camera
                anchors.fill: parent
                anchors.margins: 2
                fillMode: VideoOutput.PreserveAspectFit
                autoOrientation: true
            }

            // Overlay status text
            Label {
                anchors.centerIn: parent
                text: camera.availability === Camera.Available ? "" : "Camera not available"
                color: "white"
                font.pixelSize: 18
                visible: camera.availability !== Camera.Available
                background: Rectangle {
                    color: "#000000"
                    opacity: 0.7
                    radius: 8
                }
                padding: 20
            }
        }

        // Camera info
        Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20

                Label {
                    text: "Status:"
                    color: text
                    font.pixelSize: 16
                    font.bold: true
                }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: camera.cameraStatus === Camera.ActiveStatus ? success : danger
                }

                Label {
                    text: camera.cameraStatus === Camera.ActiveStatus ? "Active" :
                          camera.cameraStatus === Camera.StartingStatus ? "Starting..." :
                          camera.cameraStatus === Camera.StoppingStatus ? "Stopping..." :
                          camera.cameraStatus === Camera.StandbyStatus ? "Standby" :
                          "Unavailable"
                    color: hint
                    font.pixelSize: 14
                    Layout.fillWidth: true
                }

                Button {
                    text: camera.cameraStatus === Camera.ActiveStatus ? "Stop Camera" : "Start Camera"
                    implicitHeight: 40

                    background: Rectangle {
                        color: parent.pressed ? "#2563EB" : accent
                        radius: 6
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        soundManager.playClick()
                        if (camera.cameraStatus === Camera.ActiveStatus) {
                            camera.stop()
                        } else {
                            camera.start()
                        }
                    }
                }
            }
        }
    }

    Component.onDestruction: {
        camera.stop()
    }
}
