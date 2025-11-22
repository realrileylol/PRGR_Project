import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: cameraSettings
    width: 800
    height: 480

    property var win

    // Flag to prevent applyPreset during initial load
    property bool isLoading: true

    // Camera parameters
    property int shutterSpeed: 5000      // microseconds (1000-30000)
    property real gain: 2.0              // analog gain (1.0-16.0)
    property real evCompensation: 0.0    // exposure compensation (-2.0 to +2.0)
    property int frameRate: 30           // frames per second (30, 60, 90, 120)
    property string timeOfDay: "Cloudy/Shade"

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

    Component.onCompleted: {
        loadSettings()
    }

    function loadSettings() {
        var loadedShutter = settingsManager.getNumber("cameraShutterSpeed")
        var loadedGain = settingsManager.getNumber("cameraGain")
        var loadedEV = settingsManager.getNumber("cameraEV")
        var loadedFPS = settingsManager.getNumber("cameraFrameRate")
        var loadedTOD = settingsManager.getString("cameraTimeOfDay")

        shutterSpeed = loadedShutter || 5000
        gain = loadedGain || 2.0
        evCompensation = loadedEV || 0.0
        frameRate = loadedFPS || 30
        timeOfDay = loadedTOD || "Cloudy/Shade"

        console.log("Loaded camera settings:", "Shutter:", shutterSpeed, "Gain:", gain, "EV:", evCompensation, "FPS:", frameRate, "TOD:", timeOfDay)

        // Update combo box to match loaded timeOfDay
        for (var i = 0; i < timeOfDaySelect.model.length; i++) {
            if (timeOfDaySelect.model[i] === timeOfDay) {
                timeOfDaySelect.currentIndex = i
                break
            }
        }

        // Loading complete - allow preset changes from now on
        isLoading = false
    }

    function saveSettings() {
        settingsManager.setNumber("cameraShutterSpeed", shutterSpeed)
        settingsManager.setNumber("cameraGain", gain)
        settingsManager.setNumber("cameraEV", evCompensation)
        settingsManager.setNumber("cameraFrameRate", frameRate)
        settingsManager.setString("cameraTimeOfDay", timeOfDay)

        console.log("Saved camera settings:", "Shutter:", shutterSpeed, "Gain:", gain, "EV:", evCompensation, "FPS:", frameRate, "TOD:", timeOfDay)
    }

    function applyPreset(preset) {
        timeOfDay = preset
        switch(preset) {
            case "Spin Detection":
                shutterSpeed = 1500
                gain = 8.0
                evCompensation = 0.0
                frameRate = 100
                break
            case "Early AM/Dusk/Indoor":
                shutterSpeed = 15000
                gain = 6.0
                evCompensation = 0.5
                frameRate = 30
                break
            case "Midday/Texas Sun":
                shutterSpeed = 2000
                gain = 1.5
                evCompensation = -0.5
                frameRate = 30
                break
            case "Cloudy/Shade":
                shutterSpeed = 5000
                gain = 2.0
                evCompensation = 0.0
                frameRate = 30
                break
            case "Indoor with IR":
                shutterSpeed = 10000
                gain = 4.0
                evCompensation = 0.0
                frameRate = 30
                break
        }
    }

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Back"
                implicitWidth: 90
                implicitHeight: 42
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
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    soundManager.playClick()
                    saveSettings()
                    stack.goBack()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Camera Settings"
                color: text
                font.pixelSize: 22
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Item { implicitWidth: 90; implicitHeight: 42 }
        }

        Text {
            text: "Adjust camera exposure based on lighting conditions. Test changes with the Camera screen."
            color: hint
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Scrollable content area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.parent.width
                spacing: 12

                // --- Time of Day Preset ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: 10
                    color: card
                    border.color: edge
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 12

                        Text {
                            text: "Time of Day Preset:"
                            color: cameraSettings.text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        ComboBox {
                            id: timeOfDaySelect
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50

                            model: [
                                "Spin Detection",
                                "Early AM/Dusk/Indoor",
                                "Midday/Texas Sun",
                                "Cloudy/Shade",
                                "Indoor with IR"
                            ]

                            currentIndex: 3

                            onCurrentTextChanged: {
                                // Only apply preset if user manually changed it (not during initial load)
                                if (currentText && !isLoading) {
                                    applyPreset(currentText)
                                }
                            }

                            background: Rectangle {
                                color: "#F5F7FA"
                                radius: 8
                                border.color: timeOfDaySelect.pressed ? accent : edge
                                border.width: 2
                            }

                            contentItem: Text {
                                leftPadding: 12
                                text: timeOfDaySelect.displayText
                                font.pixelSize: 14
                                color: cameraSettings.text
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            delegate: ItemDelegate {
                                width: timeOfDaySelect.width
                                height: 45

                                contentItem: Text {
                                    text: modelData
                                    color: cameraSettings.text
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 12
                                }

                                background: Rectangle {
                                    color: parent.highlighted ? "#E8F0FE" : "white"
                                }
                            }

                            popup: Popup {
                                y: timeOfDaySelect.height + 5
                                width: timeOfDaySelect.width
                                implicitHeight: contentItem.implicitHeight
                                padding: 1

                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: timeOfDaySelect.popup.visible ? timeOfDaySelect.delegateModel : null
                                    currentIndex: timeOfDaySelect.highlightedIndex
                                    ScrollIndicator.vertical: ScrollIndicator { }
                                }

                                background: Rectangle {
                                    color: card
                                    border.color: edge
                                    border.width: 2
                                    radius: 8
                                }
                            }
                        }

                        Text {
                            text: "Select a preset to auto-configure exposure settings"
                            color: hint
                            font.pixelSize: 12
                        }
                    }
                }

                // --- Shutter Speed ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: 10
                    color: card
                    border.color: edge
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Text {
                            text: "Shutter Speed: " + (shutterSpeed / 1000).toFixed(1) + " ms (" + shutterSpeed + " µs)"
                            color: cameraSettings.text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Slider {
                            id: shutterSlider
                            Layout.fillWidth: true
                            from: 1000
                            to: 30000
                            stepSize: 500
                            value: shutterSpeed
                            onValueChanged: shutterSpeed = value

                            background: Rectangle {
                                x: shutterSlider.leftPadding
                                y: shutterSlider.topPadding + shutterSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: shutterSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: edge

                                Rectangle {
                                    width: shutterSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: accent
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: shutterSlider.leftPadding + shutterSlider.visualPosition * (shutterSlider.availableWidth - width)
                                y: shutterSlider.topPadding + shutterSlider.availableHeight / 2 - height / 2
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 12
                                color: shutterSlider.pressed ? "#2563EB" : accent
                                border.color: cameraSettings.text
                                border.width: 2
                            }
                        }

                        Text {
                            text: shutterSpeed < 3000 ? "Fast shutter - bright conditions" :
                                  shutterSpeed < 10000 ? "Medium shutter - normal conditions" :
                                  "Slow shutter - low light (may blur fast motion)"
                            color: hint
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // --- Gain ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: 10
                    color: card
                    border.color: edge
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Text {
                            text: "Gain: " + gain.toFixed(1) + "x"
                            color: cameraSettings.text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Slider {
                            id: gainSlider
                            Layout.fillWidth: true
                            from: 1.0
                            to: 16.0
                            stepSize: 0.5
                            value: gain
                            onValueChanged: gain = value

                            background: Rectangle {
                                x: gainSlider.leftPadding
                                y: gainSlider.topPadding + gainSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: gainSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: edge

                                Rectangle {
                                    width: gainSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: accent
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: gainSlider.leftPadding + gainSlider.visualPosition * (gainSlider.availableWidth - width)
                                y: gainSlider.topPadding + gainSlider.availableHeight / 2 - height / 2
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 12
                                color: gainSlider.pressed ? "#2563EB" : accent
                                border.color: cameraSettings.text
                                border.width: 2
                            }
                        }

                        Text {
                            text: gain < 3.0 ? "Low gain - bright conditions, less noise" :
                                  gain < 8.0 ? "Medium gain - balanced" :
                                  "High gain - low light, more noise"
                            color: hint
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // --- EV Compensation ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: 10
                    color: card
                    border.color: edge
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Text {
                            text: "Exposure Compensation: " + (evCompensation >= 0 ? "+" : "") + evCompensation.toFixed(1) + " EV"
                            color: cameraSettings.text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Slider {
                            id: evSlider
                            Layout.fillWidth: true
                            from: -2.0
                            to: 2.0
                            stepSize: 0.1
                            value: evCompensation
                            onValueChanged: evCompensation = value

                            background: Rectangle {
                                x: evSlider.leftPadding
                                y: evSlider.topPadding + evSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: evSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: edge

                                Rectangle {
                                    width: evSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: accent
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: evSlider.leftPadding + evSlider.visualPosition * (evSlider.availableWidth - width)
                                y: evSlider.topPadding + evSlider.availableHeight / 2 - height / 2
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 12
                                color: evSlider.pressed ? "#2563EB" : accent
                                border.color: cameraSettings.text
                                border.width: 2
                            }
                        }

                        Text {
                            text: evCompensation < -0.5 ? "Darker exposure - reduce overexposure" :
                                  evCompensation > 0.5 ? "Brighter exposure - improve low light" :
                                  "Neutral exposure"
                            color: hint
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // --- Frame Rate ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: 10
                    color: card
                    border.color: edge
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Text {
                            text: "Frame Rate: " + frameRate + " fps"
                            color: cameraSettings.text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Repeater {
                                model: [30, 60, 90, 100, 120]

                                Button {
                                    text: modelData + " fps"
                                    Layout.fillWidth: true
                                    implicitHeight: 50
                                    scale: pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    background: Rectangle {
                                        color: frameRate === modelData ? accent : (parent.pressed ? "#E8F0FE" : "#F5F7FA")
                                        radius: 8
                                        border.color: frameRate === modelData ? accent : edge
                                        border.width: 2
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        color: frameRate === modelData ? "white" : cameraSettings.text
                                        font.pixelSize: 14
                                        font.bold: frameRate === modelData
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked: {
                                        soundManager.playClick()
                                        frameRate = modelData
                                    }
                                }
                            }
                        }

                        Text {
                            text: frameRate === 30 ? "Standard - Good for general use" :
                                  frameRate === 60 ? "High - Better for spin detection" :
                                  frameRate === 90 ? "Very High - Excellent spin resolution" :
                                  frameRate === 100 ? "OV9281 Optimal - Best shot detection & spin accuracy" :
                                  "Ultra High - Maximum spin accuracy (requires processing power)"
                            color: hint
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // --- Info Card ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: 10
                    color: "#E8F4FD"
                    border.color: accent
                    border.width: 2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 8

                        Text {
                            text: "💡 Camera Settings Guide"
                            color: cameraSettings.text
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: "• Spin Detection: Fast shutter (1.5ms) + high gain + 100fps for tracking ball rotation\n• Early AM/Dusk: High gain + long shutter for low light\n• Midday Sun: Low gain + fast shutter to prevent overexposure\n• Cloudy/Shade: Balanced settings for changing conditions\n• Indoor IR: Fixed settings for consistent IR lighting"
                            color: hint
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            lineHeight: 1.4
                        }

                        Text {
                            text: "Test your settings on the Camera screen!"
                            color: accent
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }

                Item { height: 10 }
            }
        }

        // --- Buttons ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Save"
                Layout.fillWidth: true
                implicitHeight: 48
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
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    soundManager.playClick()
                    saveSettings()
                }
            }

            Button {
                text: "Save & Return"
                Layout.fillWidth: true
                implicitHeight: 48
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
                    saveSettings()
                    stack.goBack()
                }
            }

            Button {
                text: "Test on Camera"
                Layout.fillWidth: true
                implicitHeight: 48
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
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    soundManager.playClick()
                    saveSettings()
                    stack.push(Qt.resolvedUrl("CameraScreen.qml"), { win: win })
                }
            }
        }
    }
}
