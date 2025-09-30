import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15


ApplicationWindow {
    id: win
    visible: true
    width: 480       // ✅ Lock width for 3.5-4" portrait screen
    height: 800      // ✅ Lock height (aspect ~16:9 portrait)
    minimumWidth: 480
    minimumHeight: 800
    maximumWidth: 480
    maximumHeight: 800
    color: "#f5f7fa" // (Optional: light background)
    title: "ProfilerV1"

    // Optional (prevents resize)
    flags: Qt.Window | Qt.MSWindowsFixedSizeDialogHint
    
    Material.theme: Material.Dark

    property alias stack: stack 

    /* ==========================================================
       GLOBAL STATE
    ========================================================== */
    property string activeProfile: "Guest"
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
    property bool useWind: false
    property bool useTemp: false
    property bool useBallType: false
    property bool useLaunchEst: true
    property real temperature: 75
    property real windSpeed: 0
    property real windDirection: 0
    property string ballCompression: "Mid-High (80–90)"

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

        function goBack() {
            if (stack.depth > 1) {
                stack.pop()
            }
        }
    }

}
