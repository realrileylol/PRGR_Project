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
    readonly property string fontFamily: "DejaVu Sans"  // Available on Raspberry Pi

    // Font sizes - consistent scale
    readonly property int fontCaption: 12    // Small labels, hints
    readonly property int fontBody: 14       // Normal text
    readonly property int fontSubtitle: 16   // Secondary headings, buttons
    readonly property int fontHeading: 20    // Section titles
    readonly property int fontTitle: 24      // Main headings
    readonly property int fontDisplay: 28    // Large emphasis

    // Set app-wide default font
    font.family: fontFamily
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

    // Load settings on startup
    Component.onCompleted: {
        loadSettings()
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

}
