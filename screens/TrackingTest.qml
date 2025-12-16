import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1e1e1e"

    property var win  // Main window reference

    // Ensure camera is running
    Component.onCompleted: {
        if (!cameraManager.previewActive) {
            cameraManager.startPreview()
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 20

            // Header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                Layout.topMargin: 20
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5

                    Text {
                        text: "Ball Tracking Test"
                        font.pixelSize: 32
                        font.bold: true
                        color: "#ffffff"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: ballTracker.status
                        font.pixelSize: 14
                        color: ballTracker.isTracking ? "#4caf50" : "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Status Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#2d2d2d"
                radius: 8
                border.color: ballTracker.isTracking ? "#4caf50" : "#666666"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            color: ballTracker.isTracking ? "#4caf50" : "#666666"

                            Text {
                                anchors.centerIn: parent
                                text: ballTracker.isTracking ? "●" : "○"
                                color: "#ffffff"
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                text: ballTracker.isTracking ? "TRACKING ACTIVE" : "Ready to Track"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                text: "Frames captured: " + ballTracker.capturedFrames
                                font.pixelSize: 14
                                color: "#cccccc"
                            }
                        }
                    }
                }
            }

            // Camera Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 360
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#000000"
                radius: 8
                border.color: "#666666"
                border.width: 2

                Image {
                    id: cameraPreview
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    source: "image://frameprovider/preview?" + Date.now()
                    cache: false

                    Timer {
                        interval: 33  // ~30 FPS preview
                        running: true
                        repeat: true
                        onTriggered: cameraPreview.source = "image://frameprovider/preview?" + Date.now()
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 10
                        text: "Live Feed (640×480 @ 187 FPS)"
                        font.pixelSize: 12
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: "#000000"
                    }

                    // Tracking indicator
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 150
                        height: 35
                        color: "#dd000000"
                        radius: 6
                        visible: ballTracker.isTracking

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "#ff0000"

                                SequentialAnimation on opacity {
                                    running: ballTracker.isTracking
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: 500 }
                                    NumberAnimation { to: 1.0; duration: 500 }
                                }
                            }

                            Text {
                                text: "TRACKING"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ff0000"
                            }
                        }
                    }
                }
            }

            // Instructions
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#2d2d2d"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    Text {
                        text: "How to use:"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: "1. Place ball in calibrated zone"
                        font.pixelSize: 13
                        color: "#cccccc"
                    }

                    Text {
                        text: "2. Click 'Arm Tracking' to start monitoring"
                        font.pixelSize: 13
                        color: "#cccccc"
                    }

                    Text {
                        text: "3. Hit the ball - system will automatically track"
                        font.pixelSize: 13
                        color: "#cccccc"
                    }

                    Text {
                        text: "4. Tracking stops after 10-60 frames captured"
                        font.pixelSize: 13
                        color: "#cccccc"
                    }

                    Text {
                        text: "5. Review results and re-arm for next shot"
                        font.pixelSize: 13
                        color: "#cccccc"
                    }
                }
            }

            // Control Buttons
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                RowLayout {
                    anchors.fill: parent
                    spacing: 15

                    Button {
                        text: ballTracker.isTracking ? "Disarm Tracking" : "Arm Tracking"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        font.pixelSize: 18
                        font.bold: true
                        enabled: cameraCalibration.isBallZoneCalibrated && cameraCalibration.isZoneDefined

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: parent.enabled ? "#ffffff" : "#666666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: {
                                if (!parent.enabled) return "#3d3d3d"
                                if (ballTracker.isTracking) return parent.pressed ? "#d32f2f" : "#f44336"
                                return parent.pressed ? "#388e3c" : "#4caf50"
                            }
                            radius: 8
                            border.color: {
                                if (!parent.enabled) return "#666666"
                                if (ballTracker.isTracking) return "#d32f2f"
                                return "#388e3c"
                            }
                            border.width: 2
                        }

                        onClicked: {
                            if (ballTracker.isTracking) {
                                ballTracker.disarmTracking()
                            } else {
                                ballTracker.armTracking()
                            }
                            soundManager.playClick()
                        }

                        ToolTip.visible: !enabled && hovered
                        ToolTip.text: "Complete ball zone calibration first"
                    }

                    Button {
                        text: "Reset"
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 70
                        font.pixelSize: 18
                        font.bold: true

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: parent.pressed ? "#1976d2" : "#2196f3"
                            radius: 8
                            border.color: "#1976d2"
                            border.width: 2
                        }

                        onClicked: {
                            ballTracker.resetTracking()
                            soundManager.playClick()
                        }
                    }

                    Button {
                        text: "Back"
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 70
                        font.pixelSize: 18
                        font.bold: true

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: parent.pressed ? "#333333" : "#424242"
                            radius: 8
                            border.color: "#666666"
                            border.width: 2
                        }

                        onClicked: {
                            if (ballTracker.isTracking) {
                                ballTracker.disarmTracking()
                            }
                            stack.goBack()
                            soundManager.playClick()
                        }
                    }
                }
            }

            // Results (shown after tracking complete)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.bottomMargin: 20
                color: "#2d5016"
                radius: 8
                border.color: "#4caf50"
                border.width: 2
                visible: ballTracker.capturedFrames >= 10 && !ballTracker.isTracking

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text {
                        text: "✓ Tracking Complete"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#4caf50"
                    }

                    Text {
                        text: "Captured " + ballTracker.capturedFrames + " frames"
                        font.pixelSize: 14
                        color: "#cccccc"
                    }

                    Text {
                        text: "Ready for trajectory analysis"
                        font.pixelSize: 13
                        color: "#888888"
                    }
                }
            }
        }
    }

    // Signal connections
    Connections {
        target: ballTracker

        function onHitDetected(position) {
            console.log("Hit detected at:", position.x, position.y)
        }

        function onTrackingComplete(frameCount) {
            console.log("Tracking complete with", frameCount, "frames")
        }

        function onTrajectoryReady(trajectory) {
            console.log("Trajectory ready for analysis")
        }

        function onTrackingFailed(reason) {
            console.log("Tracking failed:", reason)
        }
    }
}
