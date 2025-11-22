import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: cameraScreen
    width: 800
    height: 480

    property var win
    property bool cameraActive: false
    property bool recordingActive: false

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
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "← Back"
                implicitWidth: 100
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
                    if (cameraActive) {
                        cameraManager.stopPreview()
                        cameraActive = false
                    }
                    stack.goBack()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Camera View"
                color: text
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Item { implicitWidth: 100; implicitHeight: 48 }
        }

        // Camera View Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#000000"
            border.color: edge
            border.width: 2

            // High-FPS camera preview (direct Qt rendering)
            Item {
                id: cameraContainer
                anchors.fill: parent
                anchors.margins: 2

                // Live camera feed from frame provider
                Image {
                    id: cameraImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: "image://frame/live"
                    cache: false  // Disable caching for real-time video
                    asynchronous: false  // Synchronous for lower latency
                    visible: cameraActive

                    // Auto-refresh when new frame is ready
                    property int frameCounter: 0
                    Connections {
                        target: cameraManager
                        enabled: cameraActive  // Only refresh when camera is active
                        function onFrameReady() {
                            // Force image reload by changing source slightly
                            cameraImage.frameCounter++
                            cameraImage.source = "image://frame/live?" + cameraImage.frameCounter
                        }
                    }
                }

                // Message when camera is not active
                Rectangle {
                    anchors.centerIn: parent
                    width: messageText.width + 40
                    height: messageText.height + 40
                    color: "#000000"
                    opacity: 0.8
                    radius: 12
                    visible: !cameraActive

                    Label {
                        id: messageText
                        anchors.centerIn: parent
                        text: "High-FPS Preview (60-100 FPS)\n\nClick 'Start Camera' below"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Status when camera is active
                Label {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 15
                    text: "● LIVE"
                    color: success
                    font.pixelSize: 16
                    font.bold: true
                    visible: cameraActive && !recordingActive
                    background: Rectangle {
                        color: "#000000"
                        opacity: 0.7
                        radius: 6
                    }
                    padding: 10
                }

                // Recording indicator
                Label {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 15
                    text: "● REC"
                    color: danger
                    font.pixelSize: 16
                    font.bold: true
                    visible: recordingActive
                    background: Rectangle {
                        color: "#000000"
                        opacity: 0.7
                        radius: 6
                    }
                    padding: 10

                    // Blinking animation
                    SequentialAnimation on opacity {
                        running: recordingActive
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }
            }
        }

        // Camera Controls
        Rectangle {
            Layout.fillWidth: true
            height: 80
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20

                // Status indicator
                ColumnLayout {
                    spacing: 8

                    Label {
                        text: "Camera Status:"
                        color: text
                        font.pixelSize: 14
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: cameraActive ? success : danger
                        }

                        Label {
                            text: cameraActive ? "Active" : "Stopped"
                            color: hint
                            font.pixelSize: 14
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Control buttons
                Button {
                    text: cameraActive ? "Stop Camera" : "Start Camera"
                    implicitHeight: 50
                    implicitWidth: 120
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
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        soundManager.playClick()
                        if (cameraActive) {
                            cameraManager.stopPreview()
                            cameraActive = false
                        } else {
                            cameraManager.startPreview()
                            cameraActive = true
                        }
                    }
                }

                // Record button
                Button {
                    text: recordingActive ? "⏹ Stop" : "⏺ Record"
                    implicitHeight: 50
                    implicitWidth: 110
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? (recordingActive ? "#B32824" : "#DA3633") : (recordingActive ? danger : "#DA3633")
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
                        if (recordingActive) {
                            cameraManager.stopRecording()
                            recordingActive = false
                        } else {
                            cameraManager.startRecording()
                            recordingActive = true
                        }
                    }
                }

                // Snapshot button
                Button {
                    text: "📸 Snapshot"
                    implicitHeight: 50
                    implicitWidth: 120
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
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        soundManager.playClick()
                        cameraManager.takeSnapshot()
                        snapshotMessage.visible = true
                        snapshotTimer.start()
                    }
                }

                // Training Mode button
                Button {
                    text: "🎓 Train"
                    implicitHeight: 50
                    implicitWidth: 100
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#7B3FF2" : "#9B5FF2"
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
                        cameraManager.startTrainingMode(100)
                        trainingMessage.visible = true
                        trainingProgressBar.value = 0
                    }
                }
            }
        }

        // Info text
        Label {
            Layout.fillWidth: true
            text: "Camera preview appears in the black area above when active"
            color: hint
            font.pixelSize: 12
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Snapshot confirmation message
    Rectangle {
        id: snapshotMessage
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 100
        width: 300
        height: 60
        radius: 10
        color: success
        visible: false
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "✓"
                color: "white"
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                text: "Snapshot saved to\nBallSnapshotTest folder"
                color: "white"
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    Timer {
        id: snapshotTimer
        interval: 2000
        onTriggered: snapshotMessage.visible = false
    }

    // Recording confirmation message
    Rectangle {
        id: recordingMessage
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 100
        width: 300
        height: 60
        radius: 10
        color: danger
        visible: false
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "✓"
                color: "white"
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                id: recordingMessageText
                text: "Recording saved to\nVideos folder"
                color: "white"
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    Timer {
        id: recordingTimer
        interval: 3000
        onTriggered: recordingMessage.visible = false
    }

    // Training mode progress message
    Rectangle {
        id: trainingMessage
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 100
        width: 350
        height: 100
        radius: 10
        color: "#9B5FF2"
        visible: false
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10
            width: parent.width - 40

            Text {
                text: "🎓 Collecting Training Data..."
                color: "white"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            // Progress bar
            Rectangle {
                id: trainingProgressBar
                Layout.fillWidth: true
                height: 20
                radius: 10
                color: "#7B3FF2"
                border.color: "white"
                border.width: 2

                property real value: 0

                Rectangle {
                    width: parent.width * (parent.value / 100)
                    height: parent.height
                    radius: parent.radius
                    color: "white"

                    Behavior on width { NumberAnimation { duration: 200 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: Math.round(trainingProgressBar.value) + "%"
                    color: trainingProgressBar.value > 50 ? "#9B5FF2" : "white"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Text {
                id: trainingProgressText
                text: "0/100 frames captured"
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    // Handle training progress updates
    Connections {
        target: cameraManager
        function onTrainingModeProgress(current, total) {
            trainingProgressBar.value = (current / total) * 100
            trainingProgressText.text = current + "/" + total + " frames captured"

            // Hide message when complete
            if (current >= total) {
                trainingCompleteTimer.start()
            }
        }

        function onRecordingSaved(filename) {
            recordingMessageText.text = "Recording saved:\n" + filename
            recordingMessage.visible = true
            recordingTimer.start()
        }
    }

    Timer {
        id: trainingCompleteTimer
        interval: 3000
        onTriggered: trainingMessage.visible = false
    }

    Component.onDestruction: {
        if (cameraActive) {
            cameraManager.stopPreview()
        }
        if (recordingActive) {
            cameraManager.stopRecording()
        }
    }
}
