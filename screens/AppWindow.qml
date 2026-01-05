import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 800
    height: 480

    property var win

    // Capture status
    property string captureStatus: "Not Started"
    property string captureColor: "gray"

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

    // Ball position update timer
    Timer {
        id: ballPositionTimer
        interval: 50  // 20 FPS for real-time tracking
        running: swipeView.currentIndex === 1  // Auto-run on metrics page
        repeat: true

        property real lastValidX: 0.5
        property real lastValidY: 0.5
        property real lastBallPixelX: 0
        property real lastBallPixelY: 0

        onTriggered: {
            // Run live ball detection (updates ballCenterX, ballCenterY, etc.)
            var result = cameraCalibration.detectBallLive()

            if (!result || !result.detected) {
                ballPositionOverlay.updateBallPosition(false, lastValidX, lastValidY)
                return
            }

            var detected = result.detected
            var ballX = result.x
            var ballY = result.y
            var inZone = result.inZone || false

            // REAL-TIME TRACKING: Show ball even if outside zone during tracking
            // (Ball flight tracking allows tracking outside hitbox after initial lock)

            // Get zone corners (trapezoid)
            var corners = cameraCalibration.zoneCorners
            if (!corners || corners.length < 4) {
                ballPositionOverlay.updateBallPosition(false, lastValidX, lastValidY)
                return
            }

            // Anti-jump filter: Reject large jumps (likely false detections)
            if (detected && lastBallPixelX > 0 && lastBallPixelY > 0) {
                var deltaX = Math.abs(ballX - lastBallPixelX)
                var deltaY = Math.abs(ballY - lastBallPixelY)
                var maxJump = 60  // Max 60 pixels per frame at 20 FPS

                if (deltaX > maxJump || deltaY > maxJump) {
                    // Reject - likely false positive, keep showing last valid position
                    ballPositionOverlay.updateBallPosition(true, lastValidX, lastValidY)
                    return
                }
            }

            // Zone corners from camera view (trapezoid):
            // corners[0] = FL (Front Left) - bottom left in camera
            // corners[1] = FR (Front Right) - bottom right in camera
            // corners[2] = BR (Back Right) - top right in camera
            // corners[3] = BL (Back Left) - top left in camera

            // Get bounding box of zone
            var minX = Math.min(corners[0].x, corners[1].x, corners[2].x, corners[3].x)
            var maxX = Math.max(corners[0].x, corners[1].x, corners[2].x, corners[3].x)
            var minY = Math.min(corners[0].y, corners[1].y, corners[2].y, corners[3].y)
            var maxY = Math.max(corners[0].y, corners[1].y, corners[2].y, corners[3].y)

            // Map pixel position to normalized 0-1
            // NOTE: If ball is outside zone, coordinates may be < 0 or > 1
            var normalizedX = (ballX - minX) / (maxX - minX)
            var normalizedY = (ballY - minY) / (maxY - minY)

            // Direct 1:1 mapping - top of camera = top of mockup
            // No Y-axis inversion needed

            // Allow tracking outside zone (for ball flight) with extended range
            // Clamp to -0.2 to 1.2 range (shows ball slightly outside hitbox visualization)
            normalizedX = Math.max(-0.2, Math.min(1.2, normalizedX))
            normalizedY = Math.max(-0.2, Math.min(1.2, normalizedY))

            // Save last valid position
            if (detected) {
                lastValidX = normalizedX
                lastValidY = normalizedY
                lastBallPixelX = ballX
                lastBallPixelY = ballY
            }

            ballPositionOverlay.updateBallPosition(detected, normalizedX, normalizedY)
        }
    }

    // Connect to capture manager signals
    Component.onCompleted: {
        captureManager.statusChanged.connect(function(status, color) {
            captureStatus = status
            captureColor = color
        })

        captureManager.shotCaptured.connect(function(shotNumber) {
            shotSavedDialog.shotNumber = shotNumber
            shotSavedDialog.open()
        })

        captureManager.errorOccurred.connect(function(errorMsg) {
            console.log("Capture error:", errorMsg)
        })
    }

    // Shot saved dialog
    Dialog {
        id: shotSavedDialog
        anchors.centerIn: parent
        width: 400
        height: 200
        modal: true
        title: "Shot Saved!"

        property int shotNumber: 0

        background: Rectangle {
            color: card
            radius: 12
            border.color: success
            border.width: 3
        }

        contentItem: ColumnLayout {
            spacing: 20
            anchors.centerIn: parent

            Text {
                text: "Shot #" + shotSavedDialog.shotNumber + " Captured"
                font.pixelSize: 24
                font.bold: true
                color: success
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "10 frames saved to ball_captures/"
                font.pixelSize: 16
                color: hint
                Layout.alignment: Qt.AlignHCenter
            }

            Button {
                text: "OK"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 50
                Layout.alignment: Qt.AlignHCenter

                background: Rectangle {
                    color: parent.pressed ? "#2D9A4F" : success
                    radius: 8
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
                    shotSavedDialog.close()
                }
            }
        }
    }

    // ORDERED metrics - always displayed in this order
    property var orderedMetrics: [
        { id: "clubSpeed", label: "CLUB SPEED", unit: "mph", getValue: function() { return win ? win.clubSpeed.toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "ballSpeed", label: "BALL SPEED", unit: "mph", getValue: function() { return win ? win.ballSpeed.toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "smash", label: "SMASH", unit: "factor", getValue: function() { return win ? win.smash.toFixed(2) : "0.00" }, color: "#F5F7FA", borderColor: edge },
        { id: "launch", label: "LAUNCH", unit: "degrees", getValue: function() { return win ? win.launchDeg.toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "spin", label: "SPIN", unit: "rpm", getValue: function() { return win ? win.spinEst : 0 }, color: "#F5F7FA", borderColor: edge },
        { id: "carry", label: "CARRY", unit: "yards", getValue: function() { return win ? win.carry : 0 }, color: "#FFF8E1", borderColor: "#FFD54F", textColor: "#F57F17", valueColor: "#E65100" },
        { id: "total", label: "TOTAL", unit: "yards", getValue: function() { return win ? win.total : 0 }, color: "#E8F5E9", borderColor: "#66BB6A", textColor: "#2E7D32", valueColor: "#1B5E20" },
        { id: "apex", label: "APEX", unit: "yards", getValue: function() { return win ? (win.carry * 0.7).toFixed(0) : "0" }, color: "#F5F7FA", borderColor: edge },
        { id: "descent", label: "DESCENT", unit: "degrees", getValue: function() { return win ? (win.launchDeg * 1.3).toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "hangTime", label: "HANG TIME", unit: "sec", getValue: function() { return win ? ((win.carry / 180) * 5.2).toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "efficiency", label: "EFFICIENCY", unit: "%", getValue: function() { return win ? ((win.smash / 1.50) * 100).toFixed(0) : "0" }, color: "#F5F7FA", borderColor: edge },
        { id: "spinLoft", label: "SPIN LOFT", unit: "degrees", getValue: function() { return win ? (win.launchDeg + 3).toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge }
    ]

    // Track which metrics are active (initially all main ones)
    property var activeMetricIds: ["clubSpeed", "ballSpeed", "smash", "launch", "spin", "carry", "total"]

    // Calculate dynamic sizing based on number of active metrics and available space
    function getMetricSize(availableWidth, availableHeight) {
        var count = activeMetricIds.length
        if (count === 0) return { width: 200, height: 200, fontSize: 48, labelSize: 14, unitSize: 12 }
        
        var spacing = 10
        var maxWidth = availableWidth - 28 // Account for margins
        
        // Try different column configurations to find the best fit
        var bestSize = 0
        var bestCols = 1
        
        for (var cols = 1; cols <= count; cols++) {
            var rows = Math.ceil(count / cols)
            var itemWidth = (maxWidth - (cols - 1) * spacing) / cols
            var itemHeight = (availableHeight - (rows - 1) * spacing) / rows
            
            // Use the smaller dimension to keep squares
            var size = Math.min(itemWidth, itemHeight)
            
            if (size > bestSize) {
                bestSize = size
                bestCols = cols
            }
        }
        
        // Clamp size to reasonable bounds
        bestSize = Math.max(bestSize, 80)
        bestSize = Math.min(bestSize, 400)
        
        var fontSize = Math.max(24, Math.min(64, bestSize * 0.28))
        var labelSize = Math.max(9, Math.min(16, bestSize * 0.08))
        var unitSize = Math.max(8, Math.min(14, bestSize * 0.07))
        
        return { width: bestSize, height: bestSize, fontSize: fontSize, labelSize: labelSize, unitSize: unitSize }
    }

    // Get active metrics in order
    function getActiveMetrics() {
        var active = []
        for (var i = 0; i < orderedMetrics.length; i++) {
            if (activeMetricIds.indexOf(orderedMetrics[i].id) !== -1) {
                active.push(orderedMetrics[i])
            }
        }
        return active
    }

    // Get available metrics (not active) in order
    function getAvailableMetrics() {
        var available = []
        for (var i = 0; i < orderedMetrics.length; i++) {
            if (activeMetricIds.indexOf(orderedMetrics[i].id) === -1) {
                available.push(orderedMetrics[i])
            }
        }
        return available
    }

    function removeMetric(metricId) {
        var newMetrics = []
        for (var i = 0; i < activeMetricIds.length; i++) {
            if (activeMetricIds[i] !== metricId) {
                newMetrics.push(activeMetricIds[i])
            }
        }
        activeMetricIds = newMetrics
    }

    function addMetrics(metricIds) {
        var newMetrics = activeMetricIds.slice()
        for (var i = 0; i < metricIds.length; i++) {
            if (newMetrics.indexOf(metricIds[i]) === -1) {
                newMetrics.push(metricIds[i])
            }
        }
        activeMetricIds = newMetrics
    }

    Rectangle { anchors.fill: parent; color: bg }

    // 3D Rotating Pixelated Golf Ball - Top-left corner
    Item {
        id: rotatingGolfBall
        width: 50
        height: 50
        x: 10
        y: 10
        z: 200

        property real rotationAngle: 0

        // Pixelated golf ball with dimples
        Canvas {
            id: golfBallCanvas
            anchors.fill: parent

            property real currentRotation: rotatingGolfBall.rotationAngle

            onCurrentRotationChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var centerX = width / 2
                var centerY = height / 2
                var radius = 23
                var pixelSize = 2.0  // Smoother pixels (was 2.5)

                // Calculate rotation offset for spinning effect
                var rotOffset = (currentRotation / 360) * 12

                // Draw pixelated ball
                for (var py = -radius; py <= radius; py += pixelSize) {
                    for (var px = -radius; px <= radius; px += pixelSize) {
                        var dist = Math.sqrt(px * px + py * py)

                        if (dist <= radius) {
                            // Smooth edge anti-aliasing
                            var edgeFade = 1.0
                            if (dist > radius - pixelSize * 1.5) {
                                edgeFade = (radius - dist) / (pixelSize * 1.5)
                                edgeFade = Math.max(0, Math.min(1, edgeFade))
                            }
                            // Calculate 3D position on sphere
                            var z = Math.sqrt(Math.max(0, radius * radius - px * px - py * py))
                            var sphereX = px
                            var sphereY = py

                            // Rotate coordinates for spinning effect
                            var rotX = sphereX * Math.cos(currentRotation * Math.PI / 180) - z * Math.sin(currentRotation * Math.PI / 180)
                            var rotZ = sphereX * Math.sin(currentRotation * Math.PI / 180) + z * Math.cos(currentRotation * Math.PI / 180)

                            // Enhanced 3D lighting - multiple light sources for depth
                            // Main light from top-right-front
                            var mainLightX = radius * 0.8
                            var mainLightY = -radius * 0.6
                            var mainLightZ = radius * 2.0

                            // Fill light from left (softer, prevents harsh shadows)
                            var fillLightX = -radius * 0.5
                            var fillLightY = 0
                            var fillLightZ = radius * 1.0

                            // Calculate surface normal (normalized sphere normal)
                            var normalX = sphereX / radius
                            var normalY = sphereY / radius
                            var normalZ = z / radius

                            // Rotate normal with sphere
                            var rotNormalX = normalX * Math.cos(currentRotation * Math.PI / 180) - normalZ * Math.sin(currentRotation * Math.PI / 180)
                            var rotNormalZ = normalX * Math.sin(currentRotation * Math.PI / 180) + normalZ * Math.cos(currentRotation * Math.PI / 180)

                            // Main light direction
                            var mainLightDirX = mainLightX - rotX
                            var mainLightDirY = mainLightY - sphereY
                            var mainLightDirZ = mainLightZ - rotZ
                            var mainLightDist = Math.sqrt(mainLightDirX*mainLightDirX + mainLightDirY*mainLightDirY + mainLightDirZ*mainLightDirZ)
                            mainLightDirX /= mainLightDist
                            mainLightDirY /= mainLightDist
                            mainLightDirZ /= mainLightDist

                            // Fill light direction
                            var fillLightDirX = fillLightX - rotX
                            var fillLightDirY = fillLightY - sphereY
                            var fillLightDirZ = fillLightZ - rotZ
                            var fillLightDist = Math.sqrt(fillLightDirX*fillLightDirX + fillLightDirY*fillLightDirY + fillLightDirZ*fillLightDirZ)
                            fillLightDirX /= fillLightDist
                            fillLightDirY /= fillLightDist
                            fillLightDirZ /= fillLightDist

                            // Main diffuse lighting (Lambertian)
                            var mainDiffuse = Math.max(0, rotNormalX * mainLightDirX + normalY * mainLightDirY + rotNormalZ * mainLightDirZ)

                            // Fill diffuse lighting
                            var fillDiffuse = Math.max(0, rotNormalX * fillLightDirX + normalY * fillLightDirY + rotNormalZ * fillLightDirZ)

                            // Specular highlight (Phong) - brighter, tighter for glossy golf ball
                            var viewDirX = 0
                            var viewDirY = 0
                            var viewDirZ = 1.0  // Camera looking straight at ball

                            // Reflect vector for main light
                            var reflectX = 2 * mainDiffuse * rotNormalX - mainLightDirX
                            var reflectY = 2 * mainDiffuse * normalY - mainLightDirY
                            var reflectZ = 2 * mainDiffuse * rotNormalZ - mainLightDirZ

                            var specDot = Math.max(0, reflectX * viewDirX + reflectY * viewDirY + reflectZ * viewDirZ)
                            var specular = Math.pow(specDot, 48) * 0.9  // Tighter, brighter highlight (was 32, 0.6)

                            // Rim lighting (edge glow) for 3D pop
                            var viewDot = Math.abs(rotNormalX * viewDirX + normalY * viewDirY + rotNormalZ * viewDirZ)
                            var rimLight = Math.pow(1.0 - viewDot, 3.0) * 0.3  // Subtle glow at edges

                            // Combine all lighting
                            var ambient = 0.35  // Base ambient light
                            var diffuse = mainDiffuse * 0.5 + fillDiffuse * 0.25  // Main + fill
                            var brightness = ambient + diffuse + specular + rimLight
                            brightness = Math.max(0.3, Math.min(1.0, brightness))

                            // Realistic dimple pattern - smaller, more numerous
                            var dimpleSize = 1.8  // Smaller dimples (was 3)
                            var dimpleSpacing = 4.5  // Closer together (was 6)
                            var isDimple = false

                            // Check if this pixel is in a dimple
                            var gridX = Math.floor((px + rotOffset) / dimpleSpacing)
                            var gridY = Math.floor(py / dimpleSpacing)
                            var offsetX = ((px + rotOffset) % dimpleSpacing + dimpleSpacing) % dimpleSpacing
                            var offsetY = (py % dimpleSpacing + dimpleSpacing) % dimpleSpacing

                            // Hexagonal offset for even rows
                            if (gridY % 2 === 0) {
                                offsetX = ((px + rotOffset + dimpleSpacing/2) % dimpleSpacing + dimpleSpacing) % dimpleSpacing
                            }

                            // Check if in dimple center with realistic depth
                            var dimpleDist = Math.sqrt(
                                Math.pow(offsetX - dimpleSpacing/2, 2) +
                                Math.pow(offsetY - dimpleSpacing/2, 2)
                            )

                            if (dimpleDist < dimpleSize/2) {
                                isDimple = true
                                // Gradual dimple depth - darker in center, lighter at edges
                                var dimpleDepth = 1.0 - (dimpleDist / (dimpleSize/2))
                                dimpleDepth = Math.pow(dimpleDepth, 1.5)  // Curved depth profile

                                // Apply shadow based on depth
                                brightness *= (1.0 - dimpleDepth * 0.35)  // Max 35% darker at center
                            }

                            // Color calculation with edge smoothing
                            var baseColor = 255
                            var colorValue = Math.floor(baseColor * brightness)

                            // Apply edge anti-aliasing
                            if (edgeFade < 1.0) {
                                ctx.fillStyle = "rgba(" + colorValue + "," + colorValue + "," + colorValue + "," + edgeFade + ")"
                            } else {
                                ctx.fillStyle = "rgb(" + colorValue + "," + colorValue + "," + colorValue + ")"
                            }

                            ctx.fillRect(
                                centerX + px,
                                centerY + py,
                                pixelSize,
                                pixelSize
                            )
                        }
                    }
                }
            }
        }

        // Continuous rotation animation
        NumberAnimation {
            target: rotatingGolfBall
            property: "rotationAngle"
            from: 0
            to: 360
            duration: 4000  // Slower, more elegant rotation
            loops: Animation.Infinite
            running: true
            onRunningChanged: {
                if (running) {
                    golfBallCanvas.requestPaint()
                }
            }
        }

        // Redraw canvas for rotation animation
        Timer {
            interval: 33  // ~30 FPS for smooth rotation
            running: true
            repeat: true
            onTriggered: {
                golfBallCanvas.requestPaint()
            }
        }
    }

    // ---------- Calculations ----------
    function estimateCarry7i(clubSpeed, spinRpm) {
        const baseCS = 92.0
        const baseCarry = 182.0
        const speedExp = 1.045
        var carry = baseCarry * Math.pow(clubSpeed / baseCS, speedExp)
        carry += (6500 - spinRpm) * 0.006
        return Math.round(carry)
    }

    function estimateTotal(carryYd, turf) {
        var roll = (turf === "firm") ? 14 : (turf === "soft") ? 7 : 10
        return carryYd + roll
    }

    // Page indicator dots
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 12
        spacing: 12
        z: 100
        
        Repeater {
            model: 2
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: swipeView.currentIndex === index ? accent : "#C8CCD4"
                
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }

    SwipeView {
        id: swipeView
        anchors.fill: parent
        currentIndex: 0

        // ========== PAGE 1: CONTROLS ==========
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // Top Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        id: profileLabel
                        text: "👤 " + (win && win.activeProfile ? win.activeProfile : "No Profile")
                        color: text
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.leftMargin: 60  // Space for golf ball logo
                    }
                    
                    Label {
                        text: "Swipe for metrics"
                        color: hint
                        font.pixelSize: 14
                        font.italic: true
                    }
                }
                
                // Profile/Settings/Camera buttons (Profile contains My Bag)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        text: "Profile"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64

                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                            radius: 12
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "#1A1D23"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            soundManager.playClick()
                            stack.openProfile()
                        }
                    }

                    Button {
                        text: "Settings"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64

                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                            radius: 12
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "#1A1D23"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            soundManager.playClick()
                            stack.openSettings()
                        }
                    }

                    Button {
                        text: "Camera"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64

                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                            radius: 12
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "#1A1D23"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            soundManager.playClick()
                            stack.openCamera()
                        }
                    }

                    Button {
                        text: "History"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64

                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                            radius: 12
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "#1A1D23"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            soundManager.playClick()
                            stack.openHistory()
                        }
                    }
                }

                // Calibration button row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Button {
                        text: "🧪 Calibration"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64

                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#2D9A4F" : success
                            radius: 12
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
                            stack.openCalibration()
                        }
                    }
                }

                // Start Capture Button with Status Indicator
                Rectangle {
                    Layout.fillWidth: true
                    height: 70
                    radius: 12
                    color: card
                    border.color: edge
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // Status Indicator Light
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: {
                                if (captureColor === "green") return success
                                if (captureColor === "red") return danger
                                if (captureColor === "yellow") return "#FFD54F"
                                return "#C8CCD4"  // gray
                            }
                            border.color: text
                            border.width: 2

                            Behavior on color { ColorAnimation { duration: 300 } }

                            // Pulsing animation when active
                            SequentialAnimation on opacity {
                                running: captureColor === "yellow" || captureColor === "green"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.5; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }

                        // Status Text
                        Text {
                            text: captureStatus
                            font.pixelSize: 16
                            font.bold: true
                            color: text
                            Layout.fillWidth: true
                        }

                        // Start Capture Button
                        Button {
                            text: "Start Capture"
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 50

                            scale: pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            background: Rectangle {
                                color: parent.pressed ? "#2D9A4F" : success
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
                                captureManager.startCapture()
                                captureStatus = "Starting..."
                                captureColor = "yellow"
                            }
                        }

                        // Stop Capture Button
                        Button {
                            text: "Stop"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 50

                            scale: pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            background: Rectangle {
                                color: parent.pressed ? "#C02927" : danger
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
                                captureManager.stopCapture()
                                captureStatus = "Stopped"
                                captureColor = "gray"
                            }
                        }
                    }
                }

                // Club Selector
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: card
                    border.color: edge
                    border.width: 2
                    Layout.fillHeight: true
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        Label {
                            text: "CLUB SELECTION"
                            color: hint
                            font.pixelSize: 13
                            font.bold: true
                        }
                        
                        ComboBox {
                            id: clubSelector
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            
                            model: win ? Object.keys(win.activeClubBag || {}) : []
                            currentIndex: 7
                            
                            Component.onCompleted: {
                                if (win && win.currentClub && model.length > 0) {
                                    var idx = model.indexOf(win.currentClub)
                                    if (idx >= 0) currentIndex = idx
                                }
                            }
                            
                            onCurrentTextChanged: {
                                if (win && win.activeClubBag && currentText) {
                                    win.currentClub = currentText
                                    win.currentLoft = win.activeClubBag[currentText] || 34.0
                                    soundManager.playClick()
                                }
                            }
                            
                            background: Rectangle {
                                color: "#F5F7FA"
                                radius: 10
                                border.color: clubSelector.pressed ? accent : "#E5E7EB"
                                border.width: 2
                            }
                            
                            contentItem: Text {
                                leftPadding: 16
                                text: {
                                    if (win && win.activeClubBag && clubSelector.displayText) {
                                        return clubSelector.displayText + " (" + 
                                               (win.activeClubBag[clubSelector.displayText] || 0).toFixed(1) + "°)"
                                    }
                                    return clubSelector.displayText
                                }
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            
                            delegate: ItemDelegate {
                                width: clubSelector.width
                                height: 56
                                
                                contentItem: Text {
                                    text: {
                                        if (win && win.activeClubBag) {
                                            return modelData + " (" + (win.activeClubBag[modelData] || 0).toFixed(1) + "°)"
                                        }
                                        return modelData
                                    }
                                    color: text
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 16
                                }
                                
                                background: Rectangle {
                                    color: parent.highlighted ? "#E8F0FE" : "white"
                                }
                            }
                            
                            popup: Popup {
                                y: clubSelector.height + 4
                                width: clubSelector.width
                                implicitHeight: Math.min(400, contentItem.implicitHeight)
                                padding: 1
                                
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: clubSelector.popup.visible ? clubSelector.delegateModel : null
                                    currentIndex: clubSelector.highlightedIndex
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                }
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: edge
                                    border.width: 2
                                    radius: 10
                                }
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }

                // Status
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: "#E9F5E9"
                    border.color: "#C6E6C3"
                    border.width: 2
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: success
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Label { 
                            text: "Ready"
                            color: "#1A5D1A"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ========== PAGE 2: METRICS ==========
        Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                radius: 14
                color: card
                border.color: edge
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 50
                        color: accent
                        radius: 14
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            
                            Label {
                                text: "Swipe back"
                                color: "white"
                                font.pixelSize: 13
                                opacity: 0.85
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Label {
                                text: "SHOT METRICS"
                                color: "white"
                                font.pixelSize: 20
                                font.bold: true
                            }
                            
                            Item { Layout.fillWidth: true }

                            Button {
                                text: "+"
                                implicitWidth: 36
                                implicitHeight: 36

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : "white"
                                    radius: 8
                                    opacity: 0.9
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: parent.pressed ? "white" : accent
                                    font.pixelSize: 24
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    addMetricDialog.selectedMetrics = []
                                    addMetricDialog.open()
                                }
                            }
                        }
                    }

                    // Metrics Grid - FILLS SPACE BETWEEN HEADER AND BUTTON
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        Flow {
                            id: metricsFlow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            
                            property var sizing: getMetricSize(width, height)
                            
                            Repeater {
                                model: getActiveMetrics()
                                
                                Rectangle {
                                    property var metric: modelData
                                    
                                    width: metricsFlow.sizing.width
                                    height: metricsFlow.sizing.height
                                    radius: 12
                                    
                                    color: metric.color || "#F5F7FA"
                                    border.color: metric.borderColor || edge
                                    border.width: 2
                                    
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressAndHold: {
                                            soundManager.playClick()
                                            deleteDialog.metricToDelete = metric.id
                                            deleteDialog.metricLabel = metric.label
                                            deleteDialog.open()
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        
                                        Label { 
                                            text: metric.label
                                            color: metric.textColor || hint
                                            font.pixelSize: metricsFlow.sizing.labelSize
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Label { 
                                            text: metric.getValue()
                                            color: metric.valueColor || text
                                            font.pixelSize: metricsFlow.sizing.fontSize
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Label {
                                            text: metric.unit
                                            color: metric.textColor || hint
                                            font.pixelSize: metricsFlow.sizing.unitSize
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // SIMULATE SHOT BUTTON
                    Button {
                        visible: win ? win.useSimulateButton : false
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 14
                        Layout.preferredHeight: visible ? 70 : 0
                        text: "SIMULATE SHOT"
                        
                        scale: pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        
                        background: Rectangle {
                            color: parent.pressed ? "#2563EB" : accent
                            radius: 14
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (!win) return
                            
                            soundManager.playClick()

                            function rand(min, max) { return min + Math.random() * (max - min) }

                            win.clubSpeed = rand(90, 96)
                            win.smash = rand(1.37, 1.41)
                            win.ballSpeed = win.clubSpeed * win.smash
                            win.spinEst = Math.round(rand(5800, 6700))
                            win.launchDeg = rand(14, 18)

                            var carryCalc = estimateCarry7i(win.clubSpeed, win.spinEst)
                            
                            if (win.useTemp && win.temperature) {
                                var temp = win.temperature
                                var tempDiff = temp - 75.0
                                var tempEffect = 0
                                
                                if (temp < 50) {
                                    tempEffect = tempDiff * 0.35
                                } else if (temp < 65) {
                                    tempEffect = tempDiff * 0.20
                                } else if (temp < 85) {
                                    tempEffect = tempDiff * 0.10
                                } else {
                                    tempEffect = tempDiff * 0.15
                                }
                                
                                var compressionMod = 1.0
                                if (win.useBallType && win.ballCompression) {
                                    var comp = win.ballCompression.toLowerCase()
                                    if (comp.includes("low") || comp.includes("soft")) {
                                        compressionMod = 0.7
                                    } else if (comp.includes("mid")) {
                                        compressionMod = 1.0
                                    } else if (comp.includes("high") || comp.includes("firm")) {
                                        compressionMod = 1.3
                                    } else if (comp.includes("range")) {
                                        compressionMod = 0.5
                                    }
                                }
                                
                                carryCalc += (tempEffect * compressionMod)
                            }
                            
                            win.carry = Math.max(0, Math.round(carryCalc))
                            win.total = estimateTotal(win.carry, "normal")

                            // Save shot to history
                            historyManager.addShot(
                                win.activeProfile,
                                win.currentClub,
                                win.clubSpeed,
                                win.ballSpeed,
                                win.smash,
                                win.launchDeg,
                                win.spinEst,
                                win.carry,
                                win.total
                            )

                            soundManager.playSuccess()
                        }
                    }
                }
            }

            // Ball Position Overlay (center popup)
            Loader {
                id: ballPositionOverlay
                source: "BallPositionOverlay.qml"
                active: swipeView.currentIndex === 1  // Auto-load on metrics page
                anchors.centerIn: parent
                z: 1000

                function updateBallPosition(detected, x, y) {
                    if (item) {
                        item.updateBallPosition(detected, x, y)
                    }
                }
            }
        }
    }

    // Delete Metric Dialog
    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: 350
        height: 200
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string metricToDelete: ""
        property string metricLabel: ""
        
        background: Rectangle {
            color: card
            radius: 12
            border.color: edge
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            Label {
                text: "Remove Metric?"
                color: text
                font.pixelSize: 20
                font.bold: true
            }
            
            Label {
                text: "Remove \"" + deleteDialog.metricLabel + "\" from your metrics view?"
                color: hint
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: text
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        deleteDialog.close()
                    }
                }
                
                Button {
                    text: "Remove"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#B02A2A" : "#DA3633"
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
                        removeMetric(deleteDialog.metricToDelete)
                        deleteDialog.close()
                    }
                }
            }
        }
    }

    // Add Metric Dialog with Multi-Select
    Dialog {
        id: addMetricDialog
        anchors.centerIn: parent
        width: 450
        height: 450
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property var selectedMetrics: []
        
        background: Rectangle {
            color: card
            radius: 12
            border.color: edge
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Label {
                text: "Add Metrics"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            Label {
                text: "Select metrics to add (will be added in order):"
                color: hint
                font.pixelSize: 14
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    
                    Repeater {
                        model: getAvailableMetrics()
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: 55
                            radius: 8
                            color: checkBox.checked ? "#E8F0FE" : "#F5F7FA"
                            border.color: edge
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                CheckBox {
                                    id: checkBox
                                    checked: addMetricDialog.selectedMetrics.indexOf(modelData.id) !== -1
                                    
                                    onCheckedChanged: {
                                        var selected = addMetricDialog.selectedMetrics.slice()
                                        var idx = selected.indexOf(modelData.id)
                                        
                                        if (checked && idx === -1) {
                                            selected.push(modelData.id)
                                        } else if (!checked && idx !== -1) {
                                            selected.splice(idx, 1)
                                        }
                                        
                                        addMetricDialog.selectedMetrics = selected
                                    }
                                }
                                
                                Label {
                                    text: modelData.label
                                    color: text
                                    font.pixelSize: 16
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                
                                Label {
                                    text: modelData.unit
                                    color: hint
                                    font.pixelSize: 13
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    soundManager.playClick()
                                    checkBox.checked = !checkBox.checked
                                }
                            }
                        }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: text
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        addMetricDialog.close()
                    }
                }
                
                Button {
                    text: "Add Selected (" + addMetricDialog.selectedMetrics.length + ")"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    enabled: addMetricDialog.selectedMetrics.length > 0
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#2563EB" : accent) : "#C8CCD4"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "white" : "#5F6B7A"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        addMetrics(addMetricDialog.selectedMetrics)
                        addMetricDialog.close()
                    }
                }
            }
        }
    }
}