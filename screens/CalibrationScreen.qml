import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    width: 800
    height: 480

    property var win

    // Theme colors
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color success: "#34C759"
    readonly property color danger: "#DA3633"

    // Calibration state
    property bool isCalibrating: false
    property int framesNeeded: 20
    property int framesCaptured: 0
    property bool isComplete: false
    property bool cameraInitialized: false

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    Component.onCompleted: {
        // Ensure camera preview is running for calibration
        if (cameraManager) {
            // Small delay to ensure everything is initialized
            Qt.callLater(function() {
                if (!cameraManager.previewActive) {
                    cameraManager.startPreview()
                }
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "← Back"
                implicitWidth: 100
                implicitHeight: 44

                background: Rectangle {
                    color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                    radius: 8
                    border.color: edge
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: text
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    soundManager.playClick()
                    StackView.view.pop()
                }
            }

            Label {
                text: "🧪 Camera Calibration"
                color: text
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 2; color: edge }

        // Main content in ScrollView
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width - 20
                spacing: 16

                // Instructions Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: card
                    border.color: edge
                    border.width: 2
                    implicitHeight: instructionsCol.implicitHeight + 32

                    ColumnLayout {
                        id: instructionsCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Label {
                            text: "📋 Instructions"
                            color: text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Label {
                            text: "1. Print or draw a checkerboard pattern (black and white squares)\n" +
                                  "2. Tape it to something flat and rigid\n" +
                                  "3. Enter the checkerboard dimensions below\n" +
                                  "4. Start calibration and capture 20-30 frames at different angles\n" +
                                  "5. Hold checkerboard 40-80cm from camera"
                            color: hint
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Setup Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: card
                    border.color: edge
                    border.width: 2
                    visible: !isCalibrating && !isComplete
                    implicitHeight: setupCol.implicitHeight + 32

                    ColumnLayout {
                        id: setupCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Label {
                            text: "⚙️ Checkerboard Setup"
                            color: text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        // Board Width
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Label {
                                text: "Interior Corners (Width)"
                                color: hint
                                font.pixelSize: 13
                            }

                            TextField {
                                id: boardWidth
                                text: "5"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 3; top: 20 }

                                background: Rectangle {
                                    color: "#F5F7FA"
                                    radius: 8
                                    border.color: boardWidth.activeFocus ? accent : edge
                                    border.width: 2
                                }
                            }
                        }

                        // Board Height
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Label {
                                text: "Interior Corners (Height)"
                                color: hint
                                font.pixelSize: 13
                            }

                            TextField {
                                id: boardHeight
                                text: "7"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 3; top: 20 }

                                background: Rectangle {
                                    color: "#F5F7FA"
                                    radius: 8
                                    border.color: boardHeight.activeFocus ? accent : edge
                                    border.width: 2
                                }
                            }
                        }

                        // Square Size
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Label {
                                text: "Square Size (millimeters)"
                                color: hint
                                font.pixelSize: 13
                            }

                            TextField {
                                id: squareSize
                                text: "30"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 10; top: 100 }

                                background: Rectangle {
                                    color: "#F5F7FA"
                                    radius: 8
                                    border.color: squareSize.activeFocus ? accent : edge
                                    border.width: 2
                                }
                            }
                        }

                        Label {
                            text: "✓ Example: 6 squares wide = 5 interior corners\n" +
                                  "✓ Measure ONE square carefully in mm"
                            color: accent
                            font.pixelSize: 12
                            font.italic: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Start Intrinsic Calibration"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60

                            scale: pressed ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            background: Rectangle {
                                color: parent.pressed ? "#2D9A4F" : success
                                radius: 10
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
                                cameraCalibration.startIntrinsicCalibration(
                                    parseInt(boardWidth.text),
                                    parseInt(boardHeight.text),
                                    parseInt(squareSize.text)
                                )
                                isCalibrating = true
                                framesCaptured = 0
                            }
                        }
                    }
                }

                // Camera Settings Card (Always visible)
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: card
                    border.color: edge
                    border.width: 2
                    implicitHeight: cameraSettingsCol.implicitHeight + 32

                    ColumnLayout {
                        id: cameraSettingsCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Label {
                            text: "📷 Camera Settings"
                            color: text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        // Shutter Speed
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Shutter Speed"
                                    color: hint
                                    font.pixelSize: 13
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: shutterSlider.value + " μs"
                                    color: text
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Slider {
                                id: shutterSlider
                                Layout.fillWidth: true
                                from: 1000
                                to: 10000
                                value: settingsManager ? settingsManager.cameraShutterSpeed : 1500
                                stepSize: 100

                                onValueChanged: {
                                    if (settingsManager) {
                                        settingsManager.setCameraShutterSpeed(Math.round(value))
                                    }
                                }

                                onPressedChanged: {
                                    if (!pressed && settingsManager) {
                                        // User released slider - restart camera to apply settings
                                        if (cameraManager && cameraManager.previewActive) {
                                            cameraManager.stopPreview()
                                            Qt.callLater(function() {
                                                cameraManager.startPreview()
                                            })
                                        }
                                    }
                                }

                                background: Rectangle {
                                    x: shutterSlider.leftPadding
                                    y: shutterSlider.topPadding + shutterSlider.availableHeight / 2 - height / 2
                                    width: shutterSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: "#E5E7EB"

                                    Rectangle {
                                        width: shutterSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: accent
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: shutterSlider.leftPadding + shutterSlider.visualPosition * (shutterSlider.availableWidth - width)
                                    y: shutterSlider.topPadding + shutterSlider.availableHeight / 2 - height / 2
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: shutterSlider.pressed ? "#2563EB" : accent
                                    border.color: "white"
                                    border.width: 2
                                }
                            }

                            Label {
                                text: "Higher = brighter image (slower shutter)"
                                color: hint
                                font.pixelSize: 11
                                font.italic: true
                            }
                        }

                        // Gain
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Gain"
                                    color: hint
                                    font.pixelSize: 13
                                }

                                Item { Layout.fillWidth: true }

                                Label {
                                    text: gainSlider.value.toFixed(1)
                                    color: text
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Slider {
                                id: gainSlider
                                Layout.fillWidth: true
                                from: 1.0
                                to: 16.0
                                value: settingsManager ? settingsManager.cameraGain : 6.0
                                stepSize: 0.5

                                onValueChanged: {
                                    if (settingsManager) {
                                        settingsManager.setCameraGain(value)
                                    }
                                }

                                onPressedChanged: {
                                    if (!pressed && settingsManager) {
                                        // User released slider - restart camera to apply settings
                                        if (cameraManager && cameraManager.previewActive) {
                                            cameraManager.stopPreview()
                                            Qt.callLater(function() {
                                                cameraManager.startPreview()
                                            })
                                        }
                                    }
                                }

                                background: Rectangle {
                                    x: gainSlider.leftPadding
                                    y: gainSlider.topPadding + gainSlider.availableHeight / 2 - height / 2
                                    width: gainSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: "#E5E7EB"

                                    Rectangle {
                                        width: gainSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: accent
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: gainSlider.leftPadding + gainSlider.visualPosition * (gainSlider.availableWidth - width)
                                    y: gainSlider.topPadding + gainSlider.availableHeight / 2 - height / 2
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: gainSlider.pressed ? "#2563EB" : accent
                                    border.color: "white"
                                    border.width: 2
                                }
                            }

                            Label {
                                text: "Higher = brighter image (more noise)"
                                color: hint
                                font.pixelSize: 11
                                font.italic: true
                            }
                        }
                    }
                }

                // Calibration in Progress Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: card
                    border.color: accent
                    border.width: 3
                    visible: isCalibrating && !isComplete
                    implicitHeight: progressCol.implicitHeight + 32

                    ColumnLayout {
                        id: progressCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Label {
                            text: "📸 Capturing Frames"
                            color: text
                            font.pixelSize: 18
                            font.bold: true
                        }

                        // Camera Preview
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 240
                            color: "#000000"
                            radius: 8
                            border.color: edge
                            border.width: 2

                            Image {
                                id: cameraPreview
                                anchors.fill: parent
                                anchors.margins: 2
                                fillMode: Image.PreserveAspectFit
                                source: "image://frameprovider/camera"
                                cache: false
                                asynchronous: true

                                onStatusChanged: {
                                    if (status === Image.Ready && !cameraInitialized) {
                                        cameraInitialized = true
                                    }
                                }

                                Timer {
                                    interval: 100  // 10 FPS refresh for preview (lighter on system)
                                    running: cameraInitialized  // Only run after first successful load
                                    repeat: true
                                    onTriggered: {
                                        // Just update the query parameter to force refresh
                                        cameraPreview.source = "image://frameprovider/camera?" + Date.now()
                                    }
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: "Waiting for camera..."
                                color: "#5F6B7A"
                                font.pixelSize: 14
                                visible: !cameraInitialized
                            }
                        }

                        // Progress
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                height: 12
                                radius: 6
                                color: "#E5E7EB"

                                Rectangle {
                                    width: parent.width * Math.min(framesCaptured / framesNeeded, 1.0)
                                    height: parent.height
                                    radius: 6
                                    color: success

                                    Behavior on width {
                                        NumberAnimation { duration: 300 }
                                    }
                                }
                            }

                            Label {
                                text: framesCaptured + " / " + framesNeeded
                                color: text
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Label {
                            text: cameraCalibration.status
                            color: hint
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Button {
                                text: "Capture Frame"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                enabled: framesCaptured < framesNeeded

                                scale: pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

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
                                    cameraCalibration.captureCalibrationFrame()
                                }
                            }

                            Button {
                                text: "Finish"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                enabled: framesCaptured >= framesNeeded

                                scale: pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.enabled ? (parent.pressed ? "#2D9A4F" : success) : "#C8CCD4"
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
                                    cameraCalibration.finishIntrinsicCalibration()
                                    isCalibrating = false
                                    isComplete = true
                                }
                            }
                        }

                        Label {
                            text: "💡 Tip: Capture frames at different angles - tilt left, right, up, down, and move to corners"
                            color: accent
                            font.pixelSize: 12
                            font.italic: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Results Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: card
                    border.color: success
                    border.width: 3
                    visible: isComplete
                    implicitHeight: resultsCol.implicitHeight + 32

                    ColumnLayout {
                        id: resultsCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Label {
                            text: "✅ Calibration Complete!"
                            color: success
                            font.pixelSize: 20
                            font.bold: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            radius: 8
                            color: "#F5F7FA"
                            border.color: edge
                            border.width: 1

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 12
                                clip: true

                                Label {
                                    text: cameraCalibration.calibrationSummary
                                    color: text
                                    font.pixelSize: 12
                                    font.family: "monospace"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Button {
                            text: "Save & Exit"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56

                            scale: pressed ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            background: Rectangle {
                                color: parent.pressed ? "#2D9A4F" : success
                                radius: 10
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
                                soundManager.playSuccess()
                                cameraCalibration.saveCalibration()
                                StackView.view.pop()
                            }
                        }
                    }
                }
            }
        }
    }

    // Connect to calibration signals
    Connections {
        target: cameraCalibration

        function onCalibrationFrameCaptured(count, success) {
            if (success) {
                framesCaptured = count
                soundManager.playSuccess()
            } else {
                soundManager.playClick()
            }
        }

        function onCalibrationComplete(success) {
            if (success) {
                soundManager.playSuccess()
            }
        }

        function onCalibrationFailed(error) {
            console.log("Calibration failed:", error)
        }
    }
}
