import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

ApplicationWindow {
    id: win
    visible: true
    width: 800
    height: 480
    minimumWidth: 800
    minimumHeight: 480
    maximumWidth: 800
    maximumHeight: 480
    color: "#f5f7fa"
    title: "ProfilerV1"
    x: 0
    y: 0

    flags: Qt.Window | Qt.FramelessWindowHint
    
    Material.theme: Material.Dark

    property alias stack: stack

    /* ==========================================================
       TYPOGRAPHY SYSTEM
    ========================================================== */
    // Font sizes - consistent scale
    readonly property int fontCaption: 12    // Small labels, hints
    readonly property int fontBody: 14       // Normal text
    readonly property int fontSubtitle: 16   // Secondary headings, buttons
    readonly property int fontHeading: 20    // Section titles
    readonly property int fontTitle: 24      // Main headings
    readonly property int fontDisplay: 28    // Large emphasis

    // Set app-wide default font size (using system font)
    font.pixelSize: fontBody

    /* ==========================================================
       GLOBAL STATE
    ========================================================== */
    property string activeProfile: ""
    property int batteryPercent: 87

    // Club session state
    // Club presets system - multiple sets per profile
    property var clubPresets: ({
        "Default Set": {
            "Driver": 10.5,
            "3 Wood": 15.0,
            "5 Wood": 18.0,
            "3 Hybrid": 19.0,
            "4 Iron": 21.0,
            "5 Iron": 24.0,
            "6 Iron": 28.0,
            "7 Iron": 34.0,
            "8 Iron": 38.0,
            "9 Iron": 42.0,
            "PW": 46.0,
            "GW": 50.0,
            "SW": 56.0,
            "LW": 60.0
        }
    })

    property string activePreset: "Default Set"
    property var activeClubBag: clubPresets["Default Set"] || {}



    // Club session state
    property string currentClub: "7 Iron"  // ADD THIS LINE
    property real currentLoft: 34.0     

    // Ball flight metrics
    property real ballSpeed: 132.1
    property real clubSpeed: 94.0
    property real smash: 1.40
    property int spinEst: 6500
    property int carry: 180
    property int total: 192

    property bool launchMeasured: false
    property real launchDeg: 16.2

    // Settings State
    property bool useSimulateButton: false
    property bool useWind: false
    property bool useTemp: false
    property bool useBallType: false
    property bool useLaunchEst: false
    property real temperature: 75
    property real windSpeed: 0
    property real windDirection: 0
    property string ballCompression: "Mid-High (80–90)"

    // Radar Test Mode - Enhanced
    property bool radarTestMode: false
    property string radarStatus: "Ready"
    property real radarSpeed: 0.0
    property int radarMagnitude: 0
    property real radarPeakSpeed: 0.0
    property int radarDetectionCount: 0
    property string radarDistanceEstimate: "---"
    property real radarAvgSpeed: 0.0
    property real radarLastSpeed: 0.0
    property bool radarPulseEffect: false
    property var radarSpeedHistory: []

    // Swing window tracking - captures peak during entire swing motion
    property bool radarSwingActive: false
    property real radarSwingPeak: 0.0
    property real radarSwingWindowSpeed: 0.0  // Best speed in current swing

    // Live speed trace for graphical visualization
    property var radarSpeedTrace: []  // Last 100 speed readings for live graph
    property int radarTraceMaxLength: 100

    // Load settings on startup
    Component.onCompleted: {
        loadSettings()

        // Connect radar signals with swing window tracking
        kld2Manager.speedUpdated.connect(function(speed) {
            if (radarTestMode) {
                // Always update magnitude
                radarMagnitude = kld2Manager.get_current_magnitude()

                // Show ALL detections >= 1 mph for debugging
                if (speed >= 1.0) {
                    // Start swing window if not active
                    if (!radarSwingActive) {
                        radarSwingActive = true
                        radarSwingPeak = speed  // Initialize with first detection
                        radarSwingWindowSpeed = speed  // Show immediately in UI
                        radarStatus = "⛳ SWING DETECTED - Tracking..."
                        console.log("🏌️ Swing window OPENED at " + speed.toFixed(1) + " mph")
                    } else {
                        // Swing already active - track peak during this swing window
                        if (speed > radarSwingPeak) {
                            radarSwingPeak = speed
                            radarSwingWindowSpeed = speed  // Update display with new peak
                            console.log("   ⬆️ NEW PEAK: " + speed.toFixed(1) + " mph")
                        } else {
                            console.log("   📊 Detection: " + speed.toFixed(1) + " mph (current peak: " + radarSwingPeak.toFixed(1) + ")")
                        }
                    }

                    // Update current detection (for reference)
                    radarSpeed = speed

                    // Add to live trace for graphical display
                    var newTrace = radarSpeedTrace.slice()  // Copy array
                    newTrace.push(speed)
                    if (newTrace.length > radarTraceMaxLength) {
                        newTrace.shift()  // Remove oldest
                    }
                    radarSpeedTrace = newTrace

                    // Estimate distance based on magnitude
                    if (radarMagnitude >= 85) {
                        radarDistanceEstimate = "< 1 ft (too close!)"
                    } else if (radarMagnitude >= 80) {
                        radarDistanceEstimate = "~2 ft"
                    } else if (radarMagnitude >= 75) {
                        radarDistanceEstimate = "~3 ft"
                    } else if (radarMagnitude >= 65) {
                        radarDistanceEstimate = "~4 ft (ideal)"
                    } else {
                        radarDistanceEstimate = "> 4 ft (weak signal)"
                    }

                    // Trigger pulse effect
                    radarPulseEffect = true
                    radarPulseTimer.restart()

                    // Reset swing close timer - keep window open while detecting motion
                    radarSwingCloseTimer.restart()
                }
            }
        })
    }

    // Timer to close swing window after inactivity (captures full swing)
    Timer {
        id: radarSwingCloseTimer
        interval: 800  // 0.8 seconds of no detection = swing complete
        onTriggered: {
            if (radarSwingActive && radarSwingPeak >= 1.0) {
                console.log("🏌️ Swing window CLOSED - Peak: " + radarSwingPeak.toFixed(1) + " mph")
                console.log("=" .repeat(60))

                // Record this swing's peak
                if (radarSwingPeak > radarPeakSpeed) {
                    radarPeakSpeed = radarSwingPeak
                }

                // Count this swing
                radarDetectionCount++
                radarSpeedHistory.push(radarSwingPeak)

                // Calculate average
                var sum = 0
                for (var i = 0; i < radarSpeedHistory.length; i++) {
                    sum += radarSpeedHistory[i]
                }
                radarAvgSpeed = sum / radarSpeedHistory.length

                radarStatus = "✅ Swing #" + radarDetectionCount + ": " + radarSwingPeak.toFixed(1) + " mph (PEAK)"

                // Close swing window
                radarSwingActive = false
                radarSwingPeak = 0.0
            }
        }
    }

    // Timer to reset pulse effect
    Timer {
        id: radarPulseTimer
        interval: 300
        onTriggered: radarPulseEffect = false
    }

    // Save settings when they change
    onActiveProfileChanged: settingsManager.setString("activeProfile", activeProfile)
    onCurrentClubChanged: settingsManager.setString("currentClub", currentClub)
    onCurrentLoftChanged: settingsManager.setNumber("currentLoft", currentLoft)
    onBallSpeedChanged: settingsManager.setNumber("ballSpeed", ballSpeed)
    onClubSpeedChanged: settingsManager.setNumber("clubSpeed", clubSpeed)
    onSmashChanged: settingsManager.setNumber("smash", smash)
    onSpinEstChanged: settingsManager.setNumber("spinEst", spinEst)
    onCarryChanged: settingsManager.setNumber("carry", carry)
    onTotalChanged: settingsManager.setNumber("total", total)
    onLaunchDegChanged: settingsManager.setNumber("launchDeg", launchDeg)
    onUseSimulateButtonChanged: settingsManager.setBool("useSimulateButton", useSimulateButton)
    onUseWindChanged: settingsManager.setBool("useWind", useWind)
    onUseTempChanged: settingsManager.setBool("useTemp", useTemp)
    onUseBallTypeChanged: settingsManager.setBool("useBallType", useBallType)
    onUseLaunchEstChanged: settingsManager.setBool("useLaunchEst", useLaunchEst)
    onTemperatureChanged: settingsManager.setNumber("temperature", temperature)
    onWindSpeedChanged: settingsManager.setNumber("windSpeed", windSpeed)
    onWindDirectionChanged: settingsManager.setNumber("windDirection", windDirection)
    onBallCompressionChanged: settingsManager.setString("ballCompression", ballCompression)

    function loadSettings() {
        var savedProfile = settingsManager.getString("activeProfile")
        if (savedProfile) activeProfile = savedProfile

        var savedClub = settingsManager.getString("currentClub")
        if (savedClub) currentClub = savedClub

        currentLoft = settingsManager.getNumber("currentLoft")
        ballSpeed = settingsManager.getNumber("ballSpeed")
        clubSpeed = settingsManager.getNumber("clubSpeed")
        smash = settingsManager.getNumber("smash")
        spinEst = settingsManager.getNumber("spinEst")
        carry = settingsManager.getNumber("carry")
        total = settingsManager.getNumber("total")
        launchDeg = settingsManager.getNumber("launchDeg")
        useSimulateButton = settingsManager.getBool("useSimulateButton")
        useWind = settingsManager.getBool("useWind")
        useTemp = settingsManager.getBool("useTemp")
        useBallType = settingsManager.getBool("useBallType")
        useLaunchEst = settingsManager.getBool("useLaunchEst")
        temperature = settingsManager.getNumber("temperature")
        windSpeed = settingsManager.getNumber("windSpeed")
        windDirection = settingsManager.getNumber("windDirection")

        var savedCompression = settingsManager.getString("ballCompression")
        if (savedCompression) ballCompression = savedCompression

        console.log("Settings loaded")
    }

    function resetAllSettings() {
        settingsManager.resetToDefaults()
        loadSettings()
        console.log("All settings reset to default")
    }

    function resetRadarStats() {
        radarPeakSpeed = 0.0
        radarDetectionCount = 0
        radarAvgSpeed = 0.0
        radarSpeed = 0.0
        radarMagnitude = 0
        radarLastSpeed = 0.0
        radarSpeedHistory = []
        radarSpeedTrace = []
        radarDistanceEstimate = "---"
        radarSwingActive = false
        radarSwingPeak = 0.0
        radarSwingWindowSpeed = 0.0
        radarStatus = "Stats reset - waiting for motion..."
    }

    function toggleRadarTestMode() {
        if (radarTestMode) {
            // Stop radar test mode
            kld2Manager.stop()
            radarTestMode = false
            radarStatus = "Stopped"
            console.log("Radar test mode stopped")
        } else {
            // Start radar test mode
            if (kld2Manager.start()) {
                radarTestMode = true
                radarStatus = "Radar active - waiting for motion..."
                resetRadarStats()
                console.log("Radar test mode started")
            } else {
                radarStatus = "Failed to start radar!"
                console.log("Failed to start radar test mode")
            }
        }
    }

/* ==========================================================
   MAIN UI STACK
========================================================== */
    StackView {
        id: stack
        anchors.fill: parent

        // Smooth slide-in animations
        pushEnter: Transition {
            PropertyAnimation {
                property: "x"
                from: width
                to: 0
                duration: 250
                easing.type: Easing.OutQuad
            }
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 250
            }
        }

        pushExit: Transition {
            PropertyAnimation {
                property: "x"
                from: 0
                to: -width * 0.3
                duration: 250
                easing.type: Easing.OutQuad
            }
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0.5
                duration: 250
            }
        }

        popEnter: Transition {
            PropertyAnimation {
                property: "x"
                from: -width * 0.3
                to: 0
                duration: 250
                easing.type: Easing.OutQuad
            }
            PropertyAnimation {
                property: "opacity"
                from: 0.5
                to: 1
                duration: 250
            }
        }

        popExit: Transition {
            PropertyAnimation {
                property: "x"
                from: 0
                to: width
                duration: 250
                easing.type: Easing.InQuad
            }
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 250
            }
        }

        Component.onCompleted: {
            var page = Qt.resolvedUrl("screens/AppWindow.qml")
            var comp = Qt.createComponent(page)
            console.log("Status:", comp.status)
            if (comp.status === Component.Error) {
                console.log("QML Load Error:", comp.errorString())
            } else {
                stack.push(comp, { win: win })
            }
        }

        // ---- SAFE NAVIGATION HELPERS ----
        function openSettings() {
            console.log("Opening:", Qt.resolvedUrl("screens/SettingsScreen.qml"))
            stack.push(Qt.resolvedUrl("screens/SettingsScreen.qml"), { win: win })
        }

        function openProfile() {
            console.log("Opening:", Qt.resolvedUrl("screens/ProfileScreen.qml"))
            stack.push(Qt.resolvedUrl("screens/ProfileScreen.qml"), { win: win })
        }

        function openMyBag() {
            console.log("Opening:", Qt.resolvedUrl("screens/MyBag.qml"))
            stack.push(Qt.resolvedUrl("screens/MyBag.qml"), { win: win })
        }

        function openCamera() {
            console.log("Opening:", Qt.resolvedUrl("screens/CameraScreen.qml"))
            stack.push(Qt.resolvedUrl("screens/CameraScreen.qml"), { win: win })
        }

        function openHistory() {
            console.log("Opening:", Qt.resolvedUrl("screens/HistoryScreen.qml"))
            stack.push(Qt.resolvedUrl("screens/HistoryScreen.qml"), { win: win })
        }

        function goBack() {
            if (stack.depth > 1) {
                stack.pop()
            }
        }
    }

    /* ==========================================================
       REPLAY GIF OVERLAY (Frame-by-frame playback)
    ========================================================== */
    Rectangle {
        id: replayOverlay
        anchors.fill: parent
        color: "#DD000000"  // Semi-transparent black background
        visible: false
        z: 9999  // On top of everything

        // Smooth fade-in animation
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }

        // Replay GIF container
        Rectangle {
            id: replayContainer
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.85, 680)
            height: Math.min(parent.height * 0.75, 510)
            color: "#1A1D23"
            radius: 20
            border.color: "#3A86FF"
            border.width: 3

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Impact Replay"
                        color: "white"
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "✕"
                        implicitWidth: 40
                        implicitHeight: 40

                        background: Rectangle {
                            color: parent.pressed ? "#DA3633" : "#5F6B7A"
                            radius: 20
                            Behavior on color { ColorAnimation { duration: 150 } }
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
                            replayOverlay.visible = false
                            soundManager.playClick()
                        }
                    }
                }

                // GIF replay area (looping playback)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    radius: 12
                    border.color: "#5F6B7A"
                    border.width: 2

                    AnimatedImage {
                        id: replayGif
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectFit
                        playing: replayOverlay.visible
                        cache: false

                        // Status monitoring
                        onStatusChanged: {
                            if (status === Image.Error) {
                                console.log("Failed to load replay GIF")
                            } else if (status === Image.Ready) {
                                console.log("Replay GIF loaded - playing frame-by-frame")
                            }
                        }
                    }

                    // Loading indicator
                    Text {
                        anchors.centerIn: parent
                        text: "Loading replay..."
                        color: "#5F6B7A"
                        font.pixelSize: 18
                        font.italic: true
                        visible: replayGif.status === Image.Loading
                    }
                }

                // Info text
                Text {
                    Layout.fillWidth: true
                    text: "40 frames before + 20 frames after impact • 0.025x speed (200ms/frame)"
                    color: "#5F6B7A"
                    font.pixelSize: 14
                    font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Scale-in animation for container
        ParallelAnimation {
            id: replayEnterAnimation
            running: false

            NumberAnimation {
                target: replayContainer
                property: "scale"
                from: 0.7
                to: 1.0
                duration: 300
                easing.type: Easing.OutBack
            }

            NumberAnimation {
                target: replayContainer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 300
            }
        }
    }

    // Handle replay ready signal from capture manager
    Connections {
        target: captureManager

        function onReplayReady(gifPath) {
            console.log("Replay GIF ready:", gifPath)
            // Load GIF into AnimatedImage (will loop automatically)
            replayGif.source = "file://" + gifPath
            replayOverlay.visible = true
            replayOverlay.opacity = 1.0
            replayEnterAnimation.restart()
        }
    }

    // Handle K-LD2 speed updates
    Connections {
        target: kld2Manager

        function onSpeedUpdated(speedMph) {
            // Update club head speed from K-LD2 radar sensor
            win.clubSpeed = speedMph
            console.log("K-LD2 Club Speed:", speedMph.toFixed(1), "mph")
        }

        function onStatusChanged(message, color) {
            console.log("K-LD2 Status:", message, "(" + color + ")")
        }
    }

    // Radar Test Mode Overlay - Enhanced
    Rectangle {
        id: radarTestOverlay
        anchors.fill: parent
        color: "#E0000000"  // Semi-transparent black background
        visible: radarTestMode
        z: 1000  // Above everything else

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Block clicks to content below
        }

        Rectangle {
            anchors.centerIn: parent
            width: 750
            height: 560
            color: "#FFFFFF"
            radius: 12
            border.color: "#3A86FF"
            border.width: 3

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Radar Test Mode"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#1A1D23"
                        Layout.fillWidth: true
                    }

                    // Session Stats (compact)
                    Rectangle {
                        implicitWidth: 120
                        implicitHeight: 32
                        color: "#F0F4F8"
                        radius: 6
                        border.color: "#D0D5DD"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "Swings:"
                                font.pixelSize: 12
                                color: "#5F6B7A"
                                font.bold: true
                            }

                            Text {
                                text: radarDetectionCount
                                font.pixelSize: 14
                                color: "#1A1D23"
                                font.bold: true
                            }
                        }
                    }
                }

                // Main Speed Display - LARGE with pulse effect
                Rectangle {
                    Layout.fillWidth: true
                    height: 110
                    color: radarSpeed > 0 ? "#E8F5E9" : "#F5F7FA"
                    radius: 10
                    border.color: radarSpeed > 0 ? "#34C759" : "#D0D5DD"
                    border.width: radarPulseEffect ? 5 : 3
                    scale: radarPulseEffect ? 1.02 : 1.0

                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }
                    Behavior on border.width { NumberAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: radarSwingActive ? "SWING PEAK (Live)" : "CURRENT SPEED"
                            font.pixelSize: 13
                            color: radarSwingActive ? "#E65100" : "#5F6B7A"
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            text: {
                                if (radarSwingActive && radarSwingWindowSpeed > 0) {
                                    return radarSwingWindowSpeed.toFixed(1) + " mph"
                                } else if (radarSpeed > 0) {
                                    return radarSpeed.toFixed(1) + " mph"
                                } else {
                                    return "---"
                                }
                            }
                            font.pixelSize: 48
                            font.bold: true
                            color: {
                                if (radarSwingActive) return "#FF6F00"  // Orange during active swing
                                if (radarSpeed > 0) return "#34C759"    // Green for detection
                                return "#9FB0C4"                        // Gray when idle
                            }
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        // Speed intensity bar
                        Rectangle {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 8
                            radius: 4
                            color: "#E0E0E0"
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: {
                                    var displaySpeed = radarSwingActive && radarSwingWindowSpeed > 0 ? radarSwingWindowSpeed : radarSpeed
                                    return Math.min(parent.width, (displaySpeed / 100) * parent.width)
                                }
                                height: parent.height
                                radius: parent.radius
                                color: {
                                    var displaySpeed = radarSwingActive && radarSwingWindowSpeed > 0 ? radarSwingWindowSpeed : radarSpeed
                                    if (displaySpeed >= 60) return "#34C759"  // Green for high speed
                                    if (displaySpeed >= 30) return "#FF9800"  // Orange for medium
                                    if (displaySpeed >= 10) return "#3A86FF"  // Blue for low
                                    return "#9FB0C4"  // Gray for very low
                                }
                                Behavior on width { NumberAnimation { duration: 300 } }
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }
                    }
                }

                // Live Speed Trace - Oscilloscope-style visualization
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    color: "#1A1D23"
                    radius: 8
                    border.color: "#3A86FF"
                    border.width: 2

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            text: "📈 LIVE SPEED TRACE (Last " + radarSpeedTrace.length + " readings)"
                            font.pixelSize: 10
                            color: "#9FB0C4"
                            font.bold: true
                        }

                        // Graph area
                        Rectangle {
                            width: parent.width
                            height: parent.height - 18
                            color: "#0A0C0F"
                            radius: 4

                            // Grid lines
                            Repeater {
                                model: 5
                                Rectangle {
                                    x: 0
                                    y: index * (parent.height / 4)
                                    width: parent.width
                                    height: 1
                                    color: "#2A2D33"
                                    opacity: 0.3
                                }
                            }

                            // Speed bars
                            Row {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 2
                                spacing: 1

                                Repeater {
                                    model: radarSpeedTrace

                                    Rectangle {
                                        width: Math.max(2, (parent.width - (radarSpeedTrace.length * 1)) / radarSpeedTrace.length)
                                        height: Math.max(2, (modelData / 100) * (parent.height - 4))
                                        color: {
                                            if (modelData >= 60) return "#34C759"  // Green
                                            if (modelData >= 30) return "#FF9800"  // Orange
                                            if (modelData >= 10) return "#3A86FF"  // Blue
                                            return "#9FB0C4"  // Gray
                                        }
                                        opacity: 0.8
                                        radius: 1

                                        // Smooth animation
                                        Behavior on height { NumberAnimation { duration: 100 } }
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                            }

                            // Current peak line marker
                            Rectangle {
                                visible: radarSwingActive && radarSwingPeak > 0
                                x: 0
                                y: parent.height - ((radarSwingPeak / 100) * parent.height)
                                width: parent.width
                                height: 2
                                color: "#FF6F00"
                                opacity: 0.7

                                Behavior on y { NumberAnimation { duration: 200 } }
                            }
                        }
                    }
                }

                // Stats Grid - Peak, Average, Distance
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8

                    // Peak Speed
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: "#FFF3E0"
                        radius: 8
                        border.color: "#FF9800"
                        border.width: 2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: "🏆 PEAK"
                                font.pixelSize: 11
                                color: "#E65100"
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: radarPeakSpeed > 0 ? radarPeakSpeed.toFixed(1) : "---"
                                font.pixelSize: 24
                                font.bold: true
                                color: "#E65100"
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "mph"
                                font.pixelSize: 10
                                color: "#E65100"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Average Speed
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: "#E3F2FD"
                        radius: 8
                        border.color: "#3A86FF"
                        border.width: 2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: "📊 AVG"
                                font.pixelSize: 11
                                color: "#1565C0"
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: radarAvgSpeed > 0 ? radarAvgSpeed.toFixed(1) : "---"
                                font.pixelSize: 24
                                font.bold: true
                                color: "#1565C0"
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "mph"
                                font.pixelSize: 10
                                color: "#1565C0"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Distance Estimate
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        color: "#F3E5F5"
                        radius: 8
                        border.color: "#9C27B0"
                        border.width: 2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: "📏 DIST"
                                font.pixelSize: 11
                                color: "#6A1B9A"
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: radarDistanceEstimate
                                font.pixelSize: 14
                                font.bold: true
                                color: "#6A1B9A"
                                Layout.alignment: Qt.AlignHCenter
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // Magnitude Display (compact)
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    color: radarMagnitude > 0 ? "#FFF8E1" : "#F5F7FA"
                    radius: 8
                    border.color: radarMagnitude > 0 ? "#FFA000" : "#D0D5DD"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "Signal Strength:"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#5F6B7A"
                        }

                        Text {
                            text: radarMagnitude > 0 ? radarMagnitude + " dB" : "---"
                            font.pixelSize: 18
                            font.bold: true
                            color: radarMagnitude > 0 ? "#F57C00" : "#9FB0C4"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }

                // Button Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "Reset Stats"
                        Layout.fillWidth: true
                        implicitHeight: 44
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#2563EB" : "#3A86FF"
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
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
                            win.resetRadarStats()
                        }
                    }

                    Button {
                        text: "Stop Test"
                        Layout.fillWidth: true
                        implicitHeight: 44
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B02A27" : "#DA3633"
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
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
                            win.toggleRadarTestMode()
                        }
                    }
                }
            }
        }
    }

}
