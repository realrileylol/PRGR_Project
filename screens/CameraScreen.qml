import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

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

    Camera {
        id: camera
        
        onErrorOccurred: function(error, errorString) {
            console.log("Camera error:", error, errorString)
        }
    }

    CaptureSession {
        camera: camera
        videoOutput: videoOutput
    }

    MediaDevices {
        id: mediaDevices
        
        Component.onCompleted: {
            console.log("Available cameras:", mediaDevices.videoInputs.length)
            for (var i = 0; i < mediaDevices.videoInputs.length; i++) {
                console.log("Camera", i, ":", mediaDevices.videoInputs[i].description)
            }
        }
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

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                anchors.margins: 2
            }

            // Overlay status text
            Label {
                anchors.centerIn: parent
                text: camera.cameraState !== Camera.ActiveState ? "Camera not active" : ""
                color: "white"
                font.pixelSize: 18
                visible: camera.cameraState !== Camera.ActiveState
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
                    color: camera.cameraState === Camera.ActiveState ? success : danger
                }

                Label {
                    text: camera.cameraState === Camera.ActiveState ? "Active" :
                          camera.cameraState === Camera.LoadingState ? "Loading..." :
                          camera.cameraState === Camera.LoadedState ? "Loaded" :
                          camera.cameraState === Camera.UnloadedState ? "Unloaded" :
                          "Unavailable"
                    color: hint
                    font.pixelSize: 14
                    Layout.fillWidth: true
                }

                Button {
                    text: camera.cameraState === Camera.ActiveState ? "Stop Camera" : "Start Camera"
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
                        if (camera.cameraState === Camera.ActiveState) {
                            camera.stop()
                        } else {
                            camera.start()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        camera.start()
    }

    Component.onDestruction: {
        camera.stop()
    }
}
