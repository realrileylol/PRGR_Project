import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: cameraTestScreen
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
    readonly property color warning: "#FF9500"

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "← Back"
                implicitWidth: 80
                implicitHeight: 40
                onClicked: {
                    soundManager.playClick()
                    stack.goBack()
                }
                background: Rectangle {
                    color: parent.pressed ? "#2D9A4F" : success
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                text: "Camera Performance Test"
                color: text
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item { implicitWidth: 80 }
        }

        // Settings Panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 12

                Text {
                    text: "Camera Settings"
                    font.pixelSize: 16
                    font.bold: true
                    color: text
                }

                // FPS Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Frame Rate:"
                        font.pixelSize: 14
                        color: text
                        Layout.preferredWidth: 120
                    }

                    Slider {
                        id: fpsSlider
                        from: 30
                        to: 120
                        stepSize: 10
                        value: 60
                        Layout.fillWidth: true
                    }

                    Text {
                        text: fpsSlider.value + " FPS"
                        font.pixelSize: 14
                        font.bold: true
                        color: accent
                        Layout.preferredWidth: 80
                    }
                }

                // Shutter Speed Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Shutter Speed:"
                        font.pixelSize: 14
                        color: text
                        Layout.preferredWidth: 120
                    }

                    Slider {
                        id: shutterSlider
                        from: 500
                        to: 15000
                        stepSize: 500
                        value: 8500
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (shutterSlider.value / 1000).toFixed(1) + " ms"
                        font.pixelSize: 14
                        font.bold: true
                        color: accent
                        Layout.preferredWidth: 80
                    }
                }

                // Gain Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Gain:"
                        font.pixelSize: 14
                        color: text
                        Layout.preferredWidth: 120
                    }

                    Slider {
                        id: gainSlider
                        from: 1.0
                        to: 10.0
                        stepSize: 0.5
                        value: 5.0
                        Layout.fillWidth: true
                    }

                    Text {
                        text: gainSlider.value.toFixed(1) + "x"
                        font.pixelSize: 14
                        font.bold: true
                        color: accent
                        Layout.preferredWidth: 80
                    }
                }

                // Preset buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Presets:"
                        font.pixelSize: 14
                        color: text
                        Layout.preferredWidth: 120
                    }

                    Button {
                        text: "Indoor"
                        implicitHeight: 35
                        implicitWidth: 80
                        onClicked: {
                            soundManager.playClick()
                            fpsSlider.value = 60
                            shutterSlider.value = 10000
                            gainSlider.value = 6.0
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#7B3FF2" : "#9B5FF2"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "Outdoor"
                        implicitHeight: 35
                        implicitWidth: 80
                        onClicked: {
                            soundManager.playClick()
                            fpsSlider.value = 100
                            shutterSlider.value = 1500
                            gainSlider.value = 2.0
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#7B3FF2" : "#9B5FF2"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "Fast"
                        implicitHeight: 35
                        implicitWidth: 80
                        onClicked: {
                            soundManager.playClick()
                            fpsSlider.value = 120
                            shutterSlider.value = 500
                            gainSlider.value = 8.0
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#7B3FF2" : "#9B5FF2"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "Current"
                        implicitHeight: 35
                        implicitWidth: 80
                        onClicked: {
                            soundManager.playClick()
                            fpsSlider.value = 60
                            shutterSlider.value = 8500
                            gainSlider.value = 5.0
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#2563EB" : accent
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Test Button
                Button {
                    text: "▶ Test These Settings"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    onClicked: {
                        soundManager.playClick()
                        cameraManager.testCameraSettings(
                            fpsSlider.value,
                            shutterSlider.value,
                            gainSlider.value
                        )
                    }
                    background: Rectangle {
                        color: parent.pressed ? "#2D9A4F" : success
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
                }
            }
        }

        // Results Panel
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "Performance Results"
                    font.pixelSize: 16
                    font.bold: true
                    color: text
                }

                Text {
                    id: resultsText
                    text: "Click 'Test These Settings' to measure actual camera performance.\n\nThe test will run for 5 seconds and show:\n• Actual FPS achieved\n• Frame timing consistency\n• Brightness level\n• Recommended settings"
                    font.pixelSize: 13
                    color: hint
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    // Handle test results
    Connections {
        target: cameraManager
        function onTestResults(fps, brightness, recommendation) {
            var result = "Test Complete!\n\n"
            result += "Actual FPS: " + fps.toFixed(1) + " FPS\n"
            result += "Brightness: " + brightness.toFixed(1) + "%\n\n"
            result += "Recommendation:\n" + recommendation

            resultsText.text = result
            resultsText.color = text
        }
    }
}
