import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24
            
            // --- Header --- PERFECTLY CENTERED
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Button {
                    text: "Back"
                    implicitWidth: 100
                    implicitHeight: 48
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#2D9A4F" : success
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    
                    contentItem: Text { 
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        
                        if (win) {
                            win.useWind = windToggle.checked
                            win.useTemp = tempToggle.checked
                            win.useBallType = ballToggle.checked
                            win.useLaunchEst = launchToggle.checked
                            win.useSimulateButton = simulateToggle.checked
                        }
                        
                        stack.goBack()
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: "Settings"
                    color: text
                    font.pixelSize: 24
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }

                Button {
                    text: "Reset to Default"
                    implicitWidth: 150
                    implicitHeight: 48
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B02A27" : danger
                        radius: 6
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
                        resetConfirmDialog.open()
                    }
                }
            }
            
            Text {
                text: "Enable or configure simulation effects:"
                font.pixelSize: 14
                color: hint
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Main Content
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 15

                    // WIND
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: windToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Wind Effects"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : accent
                                    radius: 8
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("WindSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // TEMPERATURE
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: tempToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Temperature Effects"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : accent
                                    radius: 8
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("TempSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // BALL TYPE
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: ballToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Ball Type"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : accent
                                    radius: 8
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("BallSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // LAUNCH SETTINGS
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: launchToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Launch Settings"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : accent
                                    radius: 8
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("LaunchSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // SIMULATE BUTTON
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: simulateToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Show Simulate Button"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "On Metrics Page"
                                color: hint
                                font.pixelSize: 14
                                Layout.rightMargin: 10
                            }
                        }
                    }

                    // CAMERA SETTINGS
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Text {
                                text: "Camera Settings"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : accent
                                    radius: 8
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("CameraSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // CAMERA PERFORMANCE TEST
                    Rectangle {
                        Layout.fillWidth: true
                        height: 100
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: "Camera Performance Test"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: text
                                }

                                Text {
                                    text: "Test FPS, find optimal indoor/outdoor settings"
                                    font.pixelSize: 13
                                    color: hint
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Button {
                                text: "Test"
                                implicitWidth: 90
                                implicitHeight: 50
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
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("CameraTestScreen.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // K-LD2 RADAR TEST
                    Rectangle {
                        Layout.fillWidth: true
                        height: 150
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10

                            Text {
                                text: "K-LD2 Radar Test"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                            }

                            Text {
                                id: kld2StatusText
                                text: "Status: Not Connected"
                                font.pixelSize: 13
                                color: hint
                            }

                            Text {
                                id: kld2SpeedText
                                text: "Speed: -- mph"
                                font.pixelSize: 14
                                font.bold: true
                                color: text
                                visible: false
                            }

                            RowLayout {
                                spacing: 10

                                Button {
                                    text: kld2Manager && kld2Manager.is_running ? "Stop Test" : "Start Test"
                                    implicitWidth: 120
                                    implicitHeight: 40
                                    scale: pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    background: Rectangle {
                                        color: kld2Manager && kld2Manager.is_running
                                            ? (parent.pressed ? "#B02A27" : danger)
                                            : (parent.pressed ? "#2D9A4F" : success)
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
                                        if (kld2Manager.is_running) {
                                            kld2Manager.stop()
                                            kld2SpeedText.visible = false
                                        } else {
                                            kld2Manager.start()
                                            kld2SpeedText.visible = true
                                        }
                                    }
                                }

                                Text {
                                    text: "Swing in front of radar. Detects club head speed (approaching)."
                                    font.pixelSize: 11
                                    color: hint
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Connections {
                            target: kld2Manager

                            function onSpeedUpdated(speedMph) {
                                kld2SpeedText.text = "Club Head Speed: " + speedMph.toFixed(0) + " mph"
                                kld2SpeedText.color = success
                            }

                            function onStatusChanged(message, color) {
                                kld2StatusText.text = "Status: " + message
                                kld2StatusText.color = (color === "green" ? success :
                                                       color === "red" ? danger : hint)
                            }
                        }
                    }

                    Item { height: 20 }
                }
            }
        }
    }

    // Reset confirmation dialog
    Dialog {
        id: resetConfirmDialog
        title: "Reset All Settings"
        anchors.centerIn: parent
        modal: true

        contentItem: Rectangle {
            implicitWidth: 400
            implicitHeight: 180
            color: card
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Label {
                    text: "Are you sure you want to reset ALL settings to default values?\n\nThis will reset:\n• All checkboxes and toggles\n• Temperature, wind, and ball settings\n• Current metrics and values\n• Active profile selection\n\nThis action cannot be undone!"
                    color: text
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "Cancel"
                        Layout.fillWidth: true
                        implicitHeight: 40
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : edge
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        contentItem: Text {
                            text: parent.text
                            color: text
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            soundManager.playClick()
                            resetConfirmDialog.close()
                        }
                    }

                    Button {
                        text: "Reset All"
                        Layout.fillWidth: true
                        implicitHeight: 40
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B02A27" : danger
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
                            if (win) {
                                win.resetAllSettings()

                                // Reload the checkboxes from the reset values
                                windToggle.checked = win.useWind
                                tempToggle.checked = win.useTemp
                                ballToggle.checked = win.useBallType
                                launchToggle.checked = win.useLaunchEst
                                simulateToggle.checked = win.useSimulateButton
                            }
                            resetConfirmDialog.close()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (win) {
            windToggle.checked = win.useWind || false
            tempToggle.checked = win.useTemp || false
            ballToggle.checked = win.useBallType || false
            launchToggle.checked = win.useLaunchEst || false
            simulateToggle.checked = win.useSimulateButton || false
        }
    }
}