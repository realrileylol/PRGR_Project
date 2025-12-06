import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1e1e1e"

    property var win  // Main window reference passed from navigation

    property bool ballDetected: false
    property double detectedX: 0
    property double detectedY: 0
    property double detectedRadius: 0
    property double detectedConfidence: 0

    // Ensure camera preview is active when screen loads
    Component.onCompleted: {
        if (!cameraManager.previewActive) {
            cameraManager.startPreview()
        }
    }

    // Scrollable content
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn

        ColumnLayout {
            width: parent.parent.width
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
                        text: "Ball Zone Calibration"
                        font.pixelSize: 32
                        font.bold: true
                        color: "#ffffff"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Place the golf ball anywhere within the 12\"×12\" zone"
                        font.pixelSize: 14
                        color: "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Status indicator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: cameraCalibration.isBallZoneCalibrated ? "#2d5016" : "#3d3d3d"
                radius: 8
                border.color: cameraCalibration.isBallZoneCalibrated ? "#4caf50" : "#666666"
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: cameraCalibration.isBallZoneCalibrated ? "#4caf50" : "#666666"

                        Text {
                            anchors.centerIn: parent
                            text: cameraCalibration.isBallZoneCalibrated ? "✓" : ""
                            color: "#ffffff"
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: cameraCalibration.isBallZoneCalibrated
                                  ? "Ball Zone Calibrated ✓"
                                  : "Ball Zone Not Calibrated"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: cameraCalibration.isBallZoneCalibrated
                                  ? "Position: (" + cameraCalibration.ballCenterX.toFixed(1) + ", "
                                    + cameraCalibration.ballCenterY.toFixed(1) + ") • Radius: "
                                    + cameraCalibration.ballRadius.toFixed(1) + "px"
                                  : "Place ball in zone and detect"
                            font.pixelSize: 13
                            color: "#cccccc"
                        }
                    }
                }
            }

            // Camera preview with ball visualization
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
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
                        interval: 33  // ~30 FPS
                        running: true
                        repeat: true
                        onTriggered: cameraPreview.source = "image://frameprovider/preview?" + Date.now()
                    }

                    // Overlay for ball detection visualization
                    Canvas {
                        id: ballOverlay
                        anchors.fill: parent
                        visible: ballDetected || cameraCalibration.isBallZoneCalibrated

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            if (!cameraCalibration.isBallZoneCalibrated && !ballDetected) {
                                return
                            }

                            // Calculate scaling to match Image PreserveAspectFit
                            var cameraWidth = 640
                            var cameraHeight = 480
                            var cameraAspect = cameraWidth / cameraHeight
                            var displayWidth = width
                            var displayHeight = height
                            var displayAspect = displayWidth / displayHeight

                            var scaledWidth, scaledHeight, offsetX, offsetY
                            if (displayAspect > cameraAspect) {
                                scaledHeight = displayHeight
                                scaledWidth = scaledHeight * cameraAspect
                                offsetX = (displayWidth - scaledWidth) / 2
                                offsetY = 0
                            } else {
                                scaledWidth = displayWidth
                                scaledHeight = scaledWidth / cameraAspect
                                offsetX = 0
                                offsetY = (displayHeight - scaledHeight) / 2
                            }

                            var scaleX = scaledWidth / cameraWidth
                            var scaleY = scaledHeight / cameraHeight

                            // Draw ball circle
                            var ballX = cameraCalibration.isBallZoneCalibrated
                                        ? cameraCalibration.ballCenterX
                                        : detectedX
                            var ballY = cameraCalibration.isBallZoneCalibrated
                                        ? cameraCalibration.ballCenterY
                                        : detectedY
                            var ballR = cameraCalibration.isBallZoneCalibrated
                                        ? cameraCalibration.ballRadius
                                        : detectedRadius

                            var displayX = ballX * scaleX + offsetX
                            var displayY = ballY * scaleY + offsetY
                            var displayR = ballR * Math.min(scaleX, scaleY)

                            // Draw ball detection
                            ctx.strokeStyle = cameraCalibration.isBallZoneCalibrated ? "#4caf50" : "#ff9800"
                            ctx.lineWidth = 3
                            ctx.beginPath()
                            ctx.arc(displayX, displayY, displayR, 0, 2 * Math.PI)
                            ctx.stroke()

                            // Draw crosshair at center
                            ctx.strokeStyle = cameraCalibration.isBallZoneCalibrated ? "#4caf50" : "#ff9800"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(displayX - 15, displayY)
                            ctx.lineTo(displayX + 15, displayY)
                            ctx.moveTo(displayX, displayY - 15)
                            ctx.lineTo(displayX, displayY + 15)
                            ctx.stroke()

                            // Draw 12"×12" zone (if extrinsic calibration is done)
                            if (cameraCalibration.isExtrinsicCalibrated) {
                                ctx.strokeStyle = "#2196f3"
                                ctx.lineWidth = 2
                                ctx.setLineDash([5, 5])

                                var zoneSize = 80  // pixels (approximate)
                                ctx.strokeRect(
                                    displayX - zoneSize,
                                    displayY - zoneSize,
                                    zoneSize * 2,
                                    zoneSize * 2
                                )

                                // Draw 6"×6" hit box
                                ctx.strokeStyle = "#f44336"
                                var hitBoxSize = 40  // pixels (approximate)
                                ctx.strokeRect(
                                    displayX - hitBoxSize,
                                    displayY - hitBoxSize,
                                    hitBoxSize * 2,
                                    hitBoxSize * 2
                                )
                                ctx.setLineDash([])
                            }
                        }

                        Connections {
                            target: cameraCalibration
                            function onBallZoneCalibrationChanged() {
                                ballOverlay.requestPaint()
                            }
                        }
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 10
                        text: "Live Camera Feed (640×480)"
                        font.pixelSize: 12
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: "#000000"
                    }
                }
            }

            // Instructions
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#2d2d2d"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    Text {
                        text: "Instructions:"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ffffff"
                    }

                    Text {
                        text: "1. Place golf ball on ground within 12\"×12\" zone (marked on carpet)"
                        font.pixelSize: 13
                        color: "#cccccc"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "2. Ensure ball is well-lit and clearly visible in camera view"
                        font.pixelSize: 13
                        color: "#cccccc"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "3. Scroll down and click 'Detect Ball' to automatically locate"
                        font.pixelSize: 13
                        color: "#cccccc"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "4. Green circle will appear when ball is successfully detected"
                        font.pixelSize: 13
                        color: "#cccccc"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // Buttons
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                RowLayout {
                    anchors.fill: parent
                    spacing: 15

                    Button {
                        text: "Detect Ball"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        font.pixelSize: 18
                        font.bold: true
                        enabled: cameraCalibration.isExtrinsicCalibrated

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: parent.enabled ? "#ffffff" : "#666666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: parent.enabled
                                   ? (parent.pressed ? "#1976d2" : "#2196f3")
                                   : "#3d3d3d"
                            radius: 8
                            border.color: parent.enabled ? "#1976d2" : "#666666"
                            border.width: 2
                        }

                        onClicked: {
                            console.log("Detecting ball...")
                            cameraCalibration.detectBallForZoneCalibration()
                        }

                        ToolTip.visible: !enabled && hovered
                        ToolTip.text: "Complete extrinsic calibration first"
                    }

                    Button {
                        text: "Back to Calibration"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
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
                            stack.goBack()
                        }
                    }
                }
            }

            // Status text
            Text {
                text: cameraCalibration.status
                font.pixelSize: 12
                color: "#888888"
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 20
            }
        }
    }

    // Connect to ball detection signal
    Connections {
        target: cameraCalibration

        function onBallDetectedForZone(centerX, centerY, radius, confidence) {
            console.log("Ball detected:", centerX, centerY, radius, confidence)
            ballDetected = true
            detectedX = centerX
            detectedY = centerY
            detectedRadius = radius
            detectedConfidence = confidence
            ballOverlay.requestPaint()

            // Show success message
            successTimer.start()
        }

        function onCalibrationFailed(reason) {
            console.log("Ball detection failed:", reason)
            ballDetected = false
        }

        function onCalibrationComplete(summary) {
            console.log("Ball zone calibration complete:", summary)
        }
    }

    Timer {
        id: successTimer
        interval: 3000
        onTriggered: {
            ballDetected = false
            ballOverlay.requestPaint()
        }
    }
}
