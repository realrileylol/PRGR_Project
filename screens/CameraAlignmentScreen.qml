import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: alignmentScreen
    width: 800
    height: 480

    property var win
    property bool cameraActive: false
    property bool showGrid: true
    property bool showCrosshair: true
    property bool showHitboxGuide: false

    // Theme colors
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color success: "#34C759"
    readonly property color danger: "#DA3633"
    readonly property color warning: "#FF9500"
    readonly property color guideLine: "#00FF00"

    Component.onCompleted: {
        if (cameraManager && !cameraManager.previewActive) {
            cameraManager.startPreview()
            cameraActive = true
        }
    }

    Component.onDestruction: {
        // Don't stop camera - let CalibrationScreen handle it
    }

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "← Back"
                implicitWidth: 100
                implicitHeight: 40
                onClicked: {
                    soundManager.playClick()
                    stack.goBack()
                }
                background: Rectangle {
                    color: parent.pressed ? "#2D9A4F" : success
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
            }

            Text {
                text: "Camera Alignment"
                color: text
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item { implicitWidth: 100 }
        }

        // Instructions Panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 8
            color: "#FFF3CD"
            border.color: warning
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "⚠️"
                    font.pixelSize: 24
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Physical Camera Alignment Required"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#856404"
                    }

                    Text {
                        text: "Adjust camera position so the GREEN CROSSHAIR aligns with:\n• Trajectory Cam: Target line (ball → target) • Spin Cam: Ball center at impact"
                        font.pixelSize: 12
                        color: "#856404"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Camera View with Alignment Guides
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: "#000000"
            border.color: edge
            border.width: 2

            Item {
                id: cameraContainer
                anchors.fill: parent
                anchors.margins: 2

                // Live camera feed
                Image {
                    id: cameraImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: "image://frameprovider/live"
                    cache: false
                    asynchronous: false
                    visible: cameraActive

                    property int frameCounter: 0
                    Connections {
                        target: cameraManager
                        enabled: cameraActive
                        function onFrameReady() {
                            cameraImage.frameCounter++
                            cameraImage.source = "image://frameprovider/live?" + cameraImage.frameCounter
                        }
                    }
                }

                // Alignment Overlays
                Canvas {
                    id: alignmentCanvas
                    anchors.fill: parent
                    visible: cameraActive && (showCrosshair || showGrid || showHitboxGuide)

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        // Calculate center
                        var centerX = width / 2
                        var centerY = height / 2

                        // CROSSHAIR (always in center)
                        if (showCrosshair) {
                            ctx.strokeStyle = guideLine
                            ctx.lineWidth = 2
                            ctx.globalAlpha = 0.8

                            // Vertical line
                            ctx.beginPath()
                            ctx.moveTo(centerX, 0)
                            ctx.lineTo(centerX, height)
                            ctx.stroke()

                            // Horizontal line
                            ctx.beginPath()
                            ctx.moveTo(0, centerY)
                            ctx.lineTo(width, centerY)
                            ctx.stroke()

                            // Center circle
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, 15, 0, Math.PI * 2)
                            ctx.stroke()
                        }

                        // GRID (rule of thirds)
                        if (showGrid) {
                            ctx.strokeStyle = guideLine
                            ctx.lineWidth = 1
                            ctx.globalAlpha = 0.4

                            // Vertical thirds
                            ctx.beginPath()
                            ctx.moveTo(width / 3, 0)
                            ctx.lineTo(width / 3, height)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.moveTo(2 * width / 3, 0)
                            ctx.lineTo(2 * width / 3, height)
                            ctx.stroke()

                            // Horizontal thirds
                            ctx.beginPath()
                            ctx.moveTo(0, height / 3)
                            ctx.lineTo(width, height / 3)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.moveTo(0, 2 * height / 3)
                            ctx.lineTo(width, 2 * height / 3)
                            ctx.stroke()
                        }

                        // HITBOX GUIDE (approximate for trajectory camera)
                        if (showHitboxGuide) {
                            ctx.strokeStyle = "#FF00FF"
                            ctx.lineWidth = 3
                            ctx.globalAlpha = 0.7

                            // Draw 1ft x 1ft box centered
                            var boxSize = Math.min(width, height) * 0.3  // Approximate hitbox size
                            var boxX = centerX - boxSize / 2
                            var boxY = centerY - boxSize / 2

                            ctx.strokeRect(boxX, boxY, boxSize, boxSize)

                            // Label
                            ctx.fillStyle = "#FF00FF"
                            ctx.font = "14px sans-serif"
                            ctx.globalAlpha = 0.9
                            ctx.fillText("HITBOX ZONE (1ft × 1ft)", boxX, boxY - 10)
                        }

                        ctx.globalAlpha = 1.0
                    }

                    // Redraw when camera updates
                    Connections {
                        target: cameraManager
                        enabled: cameraActive
                        function onFrameReady() {
                            alignmentCanvas.requestPaint()
                        }
                    }
                }

                // Camera inactive message
                Rectangle {
                    anchors.centerIn: parent
                    width: inactiveText.width + 40
                    height: inactiveText.height + 40
                    color: "#000000"
                    opacity: 0.8
                    radius: 12
                    visible: !cameraActive

                    Text {
                        id: inactiveText
                        anchors.centerIn: parent
                        text: "Starting camera..."
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                // FPS Counter
                Label {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    text: cameraManager.currentFPS.toFixed(0) + " FPS"
                    color: "#00FF00"
                    font.pixelSize: 16
                    font.bold: true
                    font.family: "monospace"
                    visible: cameraActive
                    background: Rectangle {
                        color: "#000000"
                        opacity: 0.7
                        radius: 4
                    }
                    padding: 8
                }

                // Camera name indicator
                Label {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 10
                    text: "● LIVE"
                    color: success
                    font.pixelSize: 14
                    font.bold: true
                    visible: cameraActive
                    background: Rectangle {
                        color: "#000000"
                        opacity: 0.7
                        radius: 4
                    }
                    padding: 8
                }
            }
        }

        // Controls Panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 8
            color: card
            border.color: edge
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 15

                // Toggle Crosshair
                Button {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    text: showCrosshair ? "✓ Crosshair" : "Crosshair"
                    checkable: true
                    checked: showCrosshair
                    onClicked: {
                        soundManager.playClick()
                        showCrosshair = !showCrosshair
                        alignmentCanvas.requestPaint()
                    }
                    background: Rectangle {
                        color: parent.checked ? accent : edge
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "white" : text
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Toggle Grid
                Button {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    text: showGrid ? "✓ Grid" : "Grid"
                    checkable: true
                    checked: showGrid
                    onClicked: {
                        soundManager.playClick()
                        showGrid = !showGrid
                        alignmentCanvas.requestPaint()
                    }
                    background: Rectangle {
                        color: parent.checked ? accent : edge
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "white" : text
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Toggle Hitbox Guide
                Button {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    text: showHitboxGuide ? "✓ Hitbox" : "Hitbox"
                    checkable: true
                    checked: showHitboxGuide
                    onClicked: {
                        soundManager.playClick()
                        showHitboxGuide = !showHitboxGuide
                        alignmentCanvas.requestPaint()
                    }
                    background: Rectangle {
                        color: parent.checked ? "#FF00FF" : edge
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "white" : text
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // Continue button
                Button {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true
                    text: "Alignment Complete →"
                    onClicked: {
                        soundManager.playClick()
                        // Return to calibration screen or go to next step
                        stack.goBack()
                    }
                    background: Rectangle {
                        color: parent.pressed ? "#0066CC" : accent
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
                }
            }
        }
    }
}
