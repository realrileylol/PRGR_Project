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

        console.log("✅ Settings loaded")
    }

    function resetAllSettings() {
        settingsManager.resetToDefaults()
        loadSettings()
        console.log("🔄 All settings reset to default")
    }

/* ==========================================================
   MAIN UI STACK
========================================================== */
    StackView {
        id: stack
        anchors.fill: parent

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

}
