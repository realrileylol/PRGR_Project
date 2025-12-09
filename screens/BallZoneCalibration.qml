import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1e1e1e"

    property var win  // Main window reference passed from navigation

    // Manual clicking state
    property string clickMode: ""  // "", "ball_edge", "zone_corners"
    property var ballEdgePoints: []
    property var zoneCornerPoints: []

    // Live ball tracking state
    property bool liveBallDetected: false
    property real liveBallX: 0
    property real liveBallY: 0
    property real liveBallRadius: 0
    property bool liveBallInZone: false

    // Live ball tracking timer
    Timer {
        id: liveTrackingTimer
        interval: 33  // ~30 fps
        running: true
        repeat: true
        onTriggered: {
            var result = cameraCalibration.detectBallLive()
            liveBallDetected = result.detected
            liveBallX = result.x
            liveBallY = result.y
            liveBallRadius = result.radius
            liveBallInZone = result.inZone
            clickOverlay.requestPaint()
        }
    }

    // Ensure camera preview is active when screen loads
    Component.onCompleted: {
        if (!cameraManager.previewActive) {
            cameraManager.startPreview()
        }
    }

    // Helper function to transform display coordinates to camera coordinates
    function transformToCamera(displayX, displayY, imageWidth, imageHeight) {
        var cameraWidth = 640
        var cameraHeight = 480
        var cameraAspect = cameraWidth / cameraHeight
        var displayAspect = imageWidth / imageHeight

        var scaledWidth, scaledHeight, offsetX, offsetY
        if (displayAspect > cameraAspect) {
            scaledHeight = imageHeight
            scaledWidth = scaledHeight * cameraAspect
            offsetX = (imageWidth - scaledWidth) / 2
            offsetY = 0
        } else {
            scaledWidth = imageWidth
            scaledHeight = scaledWidth / cameraAspect
            offsetX = 0
            offsetY = (imageHeight - scaledHeight) / 2
        }

        var scaleX = scaledWidth / cameraWidth
        var scaleY = scaledHeight / cameraHeight

        var cameraX = (displayX - offsetX) / scaleX
        var cameraY = (displayY - offsetY) / scaleY

        // Clamp to valid camera coordinates
        cameraX = Math.max(0, Math.min(cameraWidth, cameraX))
        cameraY = Math.max(0, Math.min(cameraHeight, cameraY))

        return Qt.point(cameraX, cameraY)
    }

    // Scrollable content
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn

        ColumnLayout {
            width: parent.parent.width
            spacing: 15

            // Header
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                Layout.topMargin: 15
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5

                    Text {
                        text: "Ball Zone Calibration"
                        font.pixelSize: 28
                        font.bold: true
                        color: "#ffffff"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: clickMode === "ball_edge"
                              ? "Click 3-4 points around ball edge"
                              : clickMode === "zone_corners"
                              ? "Click 4 corners of the 12\"×12\" zone"
                              : "Manual calibration workflow"
                        font.pixelSize: 13
                        color: clickMode !== "" ? "#ff9800" : "#cccccc"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Status indicator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 65
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: (cameraCalibration.isBallZoneCalibrated && cameraCalibration.isZoneDefined)
                       ? "#2d5016" : "#3d3d3d"
                radius: 8
                border.color: (cameraCalibration.isBallZoneCalibrated && cameraCalibration.isZoneDefined)
                              ? "#4caf50" : "#666666"
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: (cameraCalibration.isBallZoneCalibrated && cameraCalibration.isZoneDefined)
                               ? "#4caf50" : "#666666"

                        Text {
                            anchors.centerIn: parent
                            text: (cameraCalibration.isBallZoneCalibrated && cameraCalibration.isZoneDefined)
                                  ? "✓" : ""
                            color: "#ffffff"
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: {
                                if (cameraCalibration.isBallZoneCalibrated && cameraCalibration.isZoneDefined) {
                                    return "Ball & Zone Calibrated ✓"
                                } else if (cameraCalibration.isBallZoneCalibrated) {
                                    return "Ball Calibrated • Zone Pending"
                                } else if (cameraCalibration.isZoneDefined) {
                                    return "Zone Defined • Ball Pending"
                                } else {
                                    return "Not Calibrated"
                                }
                            }
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                        }

                        Text {
                            text: cameraCalibration.isBallZoneCalibrated
                                  ? "Ball: (" + cameraCalibration.ballCenterX.toFixed(1) + ", "
                                    + cameraCalibration.ballCenterY.toFixed(1) + ") • R: "
                                    + cameraCalibration.ballRadius.toFixed(1) + "px"
                                  : "Click ball edge points to calibrate"
                            font.pixelSize: 12
                            color: "#cccccc"
                        }
                    }
                }
            }

            // Camera preview with manual clicking
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#000000"
                radius: 8
                border.color: clickMode !== "" ? "#ff9800" : "#666666"
                border.width: clickMode !== "" ? 3 : 2

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

                    // MouseArea for manual clicking
                    MouseArea {
                        anchors.fill: parent
                        enabled: clickMode !== ""
                        cursorShape: enabled ? Qt.CrossCursor : Qt.ArrowCursor

                        onClicked: function(mouse) {
                            var camPoint = root.transformToCamera(mouse.x, mouse.y, width, height)
                            console.log("Clicked at display:", mouse.x, mouse.y, "-> camera:", camPoint.x.toFixed(1), camPoint.y.toFixed(1))

                            if (clickMode === "ball_edge") {
                                if (ballEdgePoints.length < 6) {  // Max 6 points
                                    var temp = ballEdgePoints.slice()  // Copy array
                                    temp.push(camPoint)
                                    ballEdgePoints = temp  // Reassign to trigger binding
                                    console.log("Ball edge points count:", ballEdgePoints.length)
                                    clickOverlay.requestPaint()
                                    soundManager.playClick()
                                }
                            } else if (clickMode === "zone_corners") {
                                if (zoneCornerPoints.length < 4) {
                                    var temp = zoneCornerPoints.slice()  // Copy array
                                    temp.push(camPoint)
                                    zoneCornerPoints = temp  // Reassign to trigger binding
                                    console.log("Zone corner points count:", zoneCornerPoints.length)
                                    clickOverlay.requestPaint()
                                    soundManager.playClick()
                                }
                            }
                        }
                    }

                    // Overlay for clicked points and zone box
                    Canvas {
                        id: clickOverlay
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

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

                            // Draw ball edge points (during clicking)
                            if (clickMode === "ball_edge" && ballEdgePoints.length > 0) {
                                ctx.fillStyle = "#ff9800"
                                for (var i = 0; i < ballEdgePoints.length; i++) {
                                    var pt = ballEdgePoints[i]
                                    var dispX = pt.x * scaleX + offsetX
                                    var dispY = pt.y * scaleY + offsetY

                                    ctx.beginPath()
                                    ctx.arc(dispX, dispY, 5, 0, 2 * Math.PI)
                                    ctx.fill()

                                    // Draw number
                                    ctx.fillStyle = "#ffffff"
                                    ctx.font = "bold 14px sans-serif"
                                    ctx.fillText((i + 1).toString(), dispX + 8, dispY - 8)
                                    ctx.fillStyle = "#ff9800"
                                }
                            }

                            // Draw zone corner points (during clicking)
                            if (clickMode === "zone_corners" && zoneCornerPoints.length > 0) {
                                ctx.fillStyle = "#2196f3"
                                ctx.strokeStyle = "#2196f3"
                                ctx.lineWidth = 2

                                var labels = ["FL", "FR", "BR", "BL"]
                                for (var j = 0; j < zoneCornerPoints.length; j++) {
                                    var corner = zoneCornerPoints[j]
                                    var cDispX = corner.x * scaleX + offsetX
                                    var cDispY = corner.y * scaleY + offsetY

                                    // Draw square marker
                                    ctx.strokeRect(cDispX - 6, cDispY - 6, 12, 12)

                                    // Draw label
                                    ctx.fillStyle = "#ffffff"
                                    ctx.font = "bold 12px sans-serif"
                                    ctx.fillText(labels[j], cDispX + 10, cDispY - 10)
                                    ctx.fillStyle = "#2196f3"
                                }

                                // Connect points with lines
                                if (zoneCornerPoints.length > 1) {
                                    ctx.setLineDash([5, 3])
                                    ctx.beginPath()
                                    for (var k = 0; k < zoneCornerPoints.length; k++) {
                                        var pt2 = zoneCornerPoints[k]
                                        var x = pt2.x * scaleX + offsetX
                                        var y = pt2.y * scaleY + offsetY
                                        if (k === 0) {
                                            ctx.moveTo(x, y)
                                        } else {
                                            ctx.lineTo(x, y)
                                        }
                                    }
                                    if (zoneCornerPoints.length === 4) {
                                        ctx.closePath()
                                    }
                                    ctx.stroke()
                                    ctx.setLineDash([])
                                }
                            }

                            // Draw calibrated ball (green circle) - static reference
                            if (cameraCalibration.isBallZoneCalibrated && clickMode !== "ball_edge") {
                                var ballX = cameraCalibration.ballCenterX
                                var ballY = cameraCalibration.ballCenterY
                                var ballR = cameraCalibration.ballRadius

                                var displayX = ballX * scaleX + offsetX
                                var displayY = ballY * scaleY + offsetY
                                var displayR = ballR * Math.min(scaleX, scaleY)

                                ctx.strokeStyle = "#4caf50"
                                ctx.lineWidth = 3
                                ctx.beginPath()
                                ctx.arc(displayX, displayY, displayR, 0, 2 * Math.PI)
                                ctx.stroke()

                                // Draw crosshair at center
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.moveTo(displayX - 15, displayY)
                                ctx.lineTo(displayX + 15, displayY)
                                ctx.moveTo(displayX, displayY - 15)
                                ctx.lineTo(displayX, displayY + 15)
                                ctx.stroke()
                            }

                            // Draw LIVE ball tracking (green when in zone, red when out)
                            if (liveBallDetected && clickMode !== "ball_edge") {
                                var liveX = liveBallX * scaleX + offsetX
                                var liveY = liveBallY * scaleY + offsetY
                                var liveR = liveBallRadius * Math.min(scaleX, scaleY)

                                // Green when ball is in zone, red when outside
                                ctx.strokeStyle = liveBallInZone ? "#4caf50" : "#ff0000"
                                ctx.lineWidth = 4
                                ctx.beginPath()
                                ctx.arc(liveX, liveY, liveR + 3, 0, 2 * Math.PI)
                                ctx.stroke()

                                // Draw small center dot
                                ctx.fillStyle = liveBallInZone ? "#4caf50" : "#ff0000"
                                ctx.beginPath()
                                ctx.arc(liveX, liveY, 3, 0, 2 * Math.PI)
                                ctx.fill()
                            }

                            // Draw calibrated zone boundary (always visible when defined)
                            if (cameraCalibration.isZoneDefined) {
                                var corners = cameraCalibration.zoneCorners
                                if (corners.length === 4) {
                                    // Draw solid bright blue box (always visible)
                                    ctx.strokeStyle = clickMode === "zone_corners" ? "#ff9800" : "#00bcd4"
                                    ctx.lineWidth = 3
                                    ctx.setLineDash([])

                                    ctx.beginPath()
                                    for (var m = 0; m < 4; m++) {
                                        var zx = corners[m].x * scaleX + offsetX
                                        var zy = corners[m].y * scaleY + offsetY
                                        if (m === 0) {
                                            ctx.moveTo(zx, zy)
                                        } else {
                                            ctx.lineTo(zx, zy)
                                        }
                                    }
                                    ctx.closePath()
                                    ctx.stroke()

                                    // Draw corner markers
                                    ctx.fillStyle = clickMode === "zone_corners" ? "#ff9800" : "#00bcd4"
                                    var labels = ["FL", "FR", "BR", "BL"]
                                    for (var n = 0; n < 4; n++) {
                                        var cx = corners[n].x * scaleX + offsetX
                                        var cy = corners[n].y * scaleY + offsetY

                                        // Draw small circle at corner
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, 4, 0, 2 * Math.PI)
                                        ctx.fill()

                                        // Draw label
                                        ctx.fillStyle = "#ffffff"
                                        ctx.font = "bold 12px sans-serif"
                                        ctx.strokeStyle = "#000000"
                                        ctx.lineWidth = 2
                                        ctx.strokeText(labels[n], cx + 8, cy - 8)
                                        ctx.fillText(labels[n], cx + 8, cy - 8)
                                        ctx.fillStyle = clickMode === "zone_corners" ? "#ff9800" : "#00bcd4"
                                    }
                                }
                            }
                        }

                        Connections {
                            target: cameraCalibration
                            function onBallZoneCalibrationChanged() {
                                clickOverlay.requestPaint()
                            }
                            function onZoneDefinedChanged() {
                                clickOverlay.requestPaint()
                            }
                        }
                    }

                    // Camera label
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

                    // Tracking status indicator
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.bottomMargin: 70  // Leave space for reset button
                        width: 200
                        height: 60
                        color: "#dd000000"
                        radius: 6
                        border.width: 2
                        border.color: liveBallDetected ? "#4caf50" : "#ff9800"

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: liveBallDetected ? "● TRACKING" : "○ SEARCHING..."
                                font.pixelSize: 14
                                font.bold: true
                                color: liveBallDetected ? "#4caf50" : "#ff9800"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: liveBallDetected
                                      ? (liveBallInZone ? "IN ZONE ✓" : "OUT OF ZONE")
                                      : "Place ball in zone"
                                font.pixelSize: 11
                                color: liveBallDetected
                                       ? (liveBallInZone ? "#4caf50" : "#ff5722")
                                       : "#cccccc"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: liveBallDetected
                                      ? "X:" + liveBallX.toFixed(1) + " Y:" + liveBallY.toFixed(1)
                                      : "No detection"
                                font.pixelSize: 10
                                color: "#888888"
                            }
                        }
                    }

                    // Reset tracking button
                    Button {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 10
                        width: 200
                        height: 50

                        contentItem: Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🔄 RESET"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Reset Tracking"
                                font.pixelSize: 9
                                color: "#cccccc"
                            }
                        }

                        background: Rectangle {
                            color: parent.pressed ? "#e65100" : "#ff6f00"
                            radius: 6
                            border.color: "#d84315"
                            border.width: 2
                        }

                        onClicked: {
                            cameraCalibration.resetTracking()
                            soundManager.playClick()
                        }
                    }

                    // Screenshot button
                    Button {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.rightMargin: 140  // Leave space for record button
                        anchors.bottomMargin: 10
                        width: 100
                        height: 50

                        contentItem: Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "📸 CAP"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Screenshot"
                                font.pixelSize: 9
                                color: "#cccccc"
                            }
                        }

                        background: Rectangle {
                            color: parent.pressed ? "#1976d2" : "#2196f3"
                            radius: 6
                            border.color: "#1565c0"
                            border.width: 2
                        }

                        onClicked: {
                            var filepath = cameraCalibration.captureScreenshot()
                            if (filepath) {
                                console.log("Screenshot saved: " + filepath)
                            }
                            soundManager.playClick()
                        }
                    }

                    // Record button
                    Button {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 120
                        height: 50

                        property bool recording: cameraCalibration.isRecording()

                        contentItem: Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.recording ? "⬛ STOP" : "⏺ REC"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.recording ? "Recording..." : "Start Rec"
                                font.pixelSize: 9
                                color: "#cccccc"
                            }
                        }

                        background: Rectangle {
                            color: parent.recording
                                   ? (parent.pressed ? "#c62828" : "#d32f2f")
                                   : (parent.pressed ? "#c62828" : "#f44336")
                            radius: 6
                            border.color: parent.recording ? "#b71c1c" : "#c62828"
                            border.width: 2

                            // Recording pulse animation
                            SequentialAnimation on opacity {
                                running: parent.parent.recording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.7; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }

                        onClicked: {
                            if (recording) {
                                cameraCalibration.stopRecording()
                            } else {
                                cameraCalibration.startRecording()
                            }
                            recording = cameraCalibration.isRecording()
                            soundManager.playClick()
                        }

                        // Update recording state
                        Timer {
                            interval: 100
                            running: true
                            repeat: true
                            onTriggered: parent.recording = cameraCalibration.isRecording()
                        }
                    }

                    // Click mode indicator
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 200
                        height: 35
                        color: "#dd000000"
                        radius: 6
                        visible: clickMode !== ""

                        Text {
                            anchors.centerIn: parent
                            text: clickMode === "ball_edge"
                                  ? "Ball: " + ballEdgePoints.length + "/3-4 points"
                                  : "Zone: " + zoneCornerPoints.length + "/4 corners"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#ff9800"
                        }
                    }
                }
            }

            // Step 1: Ball Edge Calibration
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#2d2d2d"
                radius: 8
                border.color: clickMode === "ball_edge" ? "#ff9800" : "#444444"
                border.width: clickMode === "ball_edge" ? 2 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "Step 1: Define Ball Position"
                        font.pixelSize: 16
                        font.bold: true
                        color: cameraCalibration.isBallZoneCalibrated ? "#4caf50" : "#ffffff"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Button {
                            text: clickMode === "ball_edge" ? "Clicking..." : "Click Ball Edge"
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 45
                            font.pixelSize: 14
                            font.bold: true
                            enabled: clickMode === "" || clickMode === "ball_edge"

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: clickMode === "ball_edge"
                                       ? "#ff9800"
                                       : (parent.pressed ? "#1976d2" : "#2196f3")
                                radius: 6
                                border.color: clickMode === "ball_edge" ? "#f57c00" : "#1976d2"
                                border.width: 2
                            }

                            onClicked: {
                                if (clickMode === "ball_edge") {
                                    // Cancel clicking mode
                                    clickMode = ""
                                    ballEdgePoints = []
                                    clickOverlay.requestPaint()
                                } else {
                                    // Start clicking mode
                                    clickMode = "ball_edge"
                                    ballEdgePoints = []
                                    clickOverlay.requestPaint()
                                }
                                soundManager.playClick()
                            }
                        }

                        Button {
                            text: "Confirm (" + ballEdgePoints.length + " pts)"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 45
                            font.pixelSize: 14
                            font.bold: true
                            enabled: ballEdgePoints.length >= 3

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.pressed ? "#388e3c" : "#4caf50")
                                       : "#3d3d3d"
                                radius: 6
                                border.color: parent.enabled ? "#388e3c" : "#666666"
                                border.width: 2
                            }

                            onClicked: {
                                console.log("Confirming ball edge points:", ballEdgePoints.length)
                                cameraCalibration.setBallEdgePoints(ballEdgePoints)
                                clickMode = ""
                                ballEdgePoints = []
                                soundManager.playClick()
                            }
                        }

                        Button {
                            text: "Retry"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 45
                            font.pixelSize: 14
                            enabled: clickMode === "ball_edge" && ballEdgePoints.length > 0

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.pressed ? "#d32f2f" : "#f44336")
                                       : "#3d3d3d"
                                radius: 6
                                border.color: parent.enabled ? "#d32f2f" : "#666666"
                                border.width: 2
                            }

                            onClicked: {
                                ballEdgePoints = []
                                clickOverlay.requestPaint()
                                soundManager.playClick()
                            }
                        }

                        Text {
                            text: cameraCalibration.isBallZoneCalibrated ? "✓ Complete" : "Click 3-4 points on ball edge"
                            font.pixelSize: 13
                            color: cameraCalibration.isBallZoneCalibrated ? "#4caf50" : "#888888"
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Step 2: Zone Boundary Calibration
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                color: "#2d2d2d"
                radius: 8
                border.color: clickMode === "zone_corners" ? "#ff9800" : "#444444"
                border.width: clickMode === "zone_corners" ? 2 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "Step 2: Define Zone Boundaries"
                        font.pixelSize: 16
                        font.bold: true
                        color: cameraCalibration.isZoneDefined ? "#4caf50" : "#ffffff"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Button {
                            text: "Use Calibration Markers"
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 45
                            font.pixelSize: 13
                            font.bold: true
                            enabled: cameraCalibration.isBallZoneCalibrated && cameraCalibration.markerCorners.length === 4

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.pressed ? "#388e3c" : "#4caf50")
                                       : "#3d3d3d"
                                radius: 6
                                border.color: parent.enabled ? "#388e3c" : "#666666"
                                border.width: 2
                            }

                            onClicked: {
                                console.log("Using extrinsic calibration markers as zone")
                                cameraCalibration.useMarkerCornersForZone()
                                soundManager.playClick()
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: enabled
                                          ? "Use the 4 markers from extrinsic calibration"
                                          : "Complete ball calibration and extrinsic calibration first"
                        }

                        Text {
                            text: "OR"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#888888"
                        }

                        Button {
                            text: clickMode === "zone_corners" ? "Clicking..." : "Click Zone Corners"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 45
                            font.pixelSize: 13
                            font.bold: true
                            enabled: (clickMode === "" || clickMode === "zone_corners") && cameraCalibration.isBallZoneCalibrated

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: clickMode === "zone_corners"
                                       ? "#ff9800"
                                       : (parent.pressed ? "#1976d2" : "#2196f3")
                                radius: 6
                                border.color: clickMode === "zone_corners" ? "#f57c00" : "#1976d2"
                                border.width: 2
                            }

                            onClicked: {
                                if (clickMode === "zone_corners") {
                                    // Cancel clicking mode
                                    clickMode = ""
                                    zoneCornerPoints = []
                                    clickOverlay.requestPaint()
                                } else {
                                    // Start clicking mode
                                    clickMode = "zone_corners"
                                    zoneCornerPoints = []
                                    clickOverlay.requestPaint()
                                }
                                soundManager.playClick()
                            }

                            ToolTip.visible: !enabled && hovered
                            ToolTip.text: "Complete ball calibration first"
                        }

                        Button {
                            text: "Confirm (" + zoneCornerPoints.length + "/4)"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 45
                            font.pixelSize: 14
                            font.bold: true
                            enabled: zoneCornerPoints.length === 4

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.pressed ? "#388e3c" : "#4caf50")
                                       : "#3d3d3d"
                                radius: 6
                                border.color: parent.enabled ? "#388e3c" : "#666666"
                                border.width: 2
                            }

                            onClicked: {
                                console.log("Confirming zone corners:", zoneCornerPoints.length)
                                cameraCalibration.setZoneCorners(zoneCornerPoints)
                                clickMode = ""
                                zoneCornerPoints = []
                                soundManager.playClick()
                            }
                        }

                        Button {
                            text: "Retry"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 45
                            font.pixelSize: 14
                            enabled: clickMode === "zone_corners" && zoneCornerPoints.length > 0

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: parent.enabled ? "#ffffff" : "#666666"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.pressed ? "#d32f2f" : "#f44336")
                                       : "#3d3d3d"
                                radius: 6
                                border.color: parent.enabled ? "#d32f2f" : "#666666"
                                border.width: 2
                            }

                            onClicked: {
                                zoneCornerPoints = []
                                clickOverlay.requestPaint()
                                soundManager.playClick()
                            }
                        }

                        Text {
                            text: cameraCalibration.isZoneDefined
                                  ? "✓ Complete"
                                  : (cameraCalibration.markerCorners.length === 4
                                     ? "Use markers or click manually"
                                     : "Click FL→FR→BR→BL corners")
                            font.pixelSize: 12
                            color: cameraCalibration.isZoneDefined ? "#4caf50" : "#888888"
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Back button
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 55
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Back to Calibration"
                    implicitWidth: 220
                    implicitHeight: 50
                    font.pixelSize: 16
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
                        soundManager.playClick()
                    }
                }
            }

            // Status text
            Text {
                text: cameraCalibration.status
                font.pixelSize: 12
                color: "#888888"
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 15
            }
        }
    }

    // Connect to calibration signals
    Connections {
        target: cameraCalibration

        function onBallDetectedForZone(centerX, centerY, radius, confidence) {
            console.log("Ball fitted from edge points:", centerX, centerY, radius)
            clickOverlay.requestPaint()
        }

        function onCalibrationFailed(reason) {
            console.log("Calibration failed:", reason)
        }

        function onCalibrationComplete(summary) {
            console.log("Calibration complete:", summary)
        }
    }
}
