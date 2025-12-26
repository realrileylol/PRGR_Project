import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Ball Position Overlay - Shows real-time ball detection in top-down view
Rectangle {
    id: root

    // Properties
    property bool ballDetected: false
    property real ballX: 0.5  // Normalized 0-1 (0 = left, 1 = right)
    property real ballY: 0.5  // Normalized 0-1 (0 = front, 1 = back)

    // Sizing
    width: 300
    height: 340

    // Styling
    color: "#DD000000"  // Semi-transparent black background
    radius: 12
    border.color: "#FF9800"  // Orange border like your mockup
    border.width: 3

    // Position overlay in center of parent
    anchors.centerIn: parent
    z: 1000  // Above everything else

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#2D2D2D"
            radius: 9

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    text: ballDetected ? "BALL POSITION" : "NO BALL DETECTED"
                    font.pixelSize: 18
                    font.bold: true
                    color: ballDetected ? "#4CAF50" : "#FF5722"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // Close button
                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30

                    text: "×"

                    background: Rectangle {
                        color: parent.pressed ? "#FF5722" : "transparent"
                        radius: 4
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        root.visible = false
                    }
                }
            }
        }

        // Hit box visualization
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20

            // Hit box outline
            Rectangle {
                id: hitBox
                anchors.fill: parent
                color: "transparent"
                border.color: "#FF9800"  // Orange
                border.width: 2
                radius: 4

                // Corner labels
                Text {
                    text: "FL"
                    color: "#FF9800"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 5
                }

                Text {
                    text: "FR"
                    color: "#FF9800"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                }

                Text {
                    text: "BL"
                    color: "#FF9800"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 5
                }

                Text {
                    text: "BR"
                    color: "#FF9800"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 5
                }

                // Ball indicator (moves based on ballX, ballY)
                Rectangle {
                    id: ballIndicator
                    width: 30
                    height: 30
                    radius: 15

                    // Position based on normalized coordinates
                    x: (hitBox.width - width) * ballX
                    y: (hitBox.height - height) * ballY

                    color: ballDetected ? "#FFFFFF" : "transparent"
                    border.color: ballDetected ? "#4CAF50" : "#FF5722"
                    border.width: 2

                    visible: true

                    // Smooth movement animation
                    Behavior on x {
                        SmoothedAnimation {
                            velocity: 500  // Pixels per second
                        }
                    }

                    Behavior on y {
                        SmoothedAnimation {
                            velocity: 500
                        }
                    }

                    // Pulsing animation when detected
                    SequentialAnimation on scale {
                        running: ballDetected
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1.0
                            to: 1.15
                            duration: 600
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 1.15
                            to: 1.0
                            duration: 600
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // Ball details (inner shadow/highlight)
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FFFFFF"
                        opacity: 0.6
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -3
                        anchors.verticalCenterOffset: -3
                        visible: ballDetected
                    }
                }

                // Center crosshair (reference point)
                Rectangle {
                    width: 20
                    height: 2
                    color: "#666"
                    opacity: 0.5
                    anchors.centerIn: parent
                }

                Rectangle {
                    width: 2
                    height: 20
                    color: "#666"
                    opacity: 0.5
                    anchors.centerIn: parent
                }

                // Warning icon when no ball detected
                Text {
                    text: "⚠"
                    font.pixelSize: 48
                    color: "#FF5722"
                    anchors.centerIn: parent
                    visible: !ballDetected
                    opacity: 0.7

                    SequentialAnimation on opacity {
                        running: !ballDetected
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0.3
                            to: 1.0
                            duration: 800
                        }

                        NumberAnimation {
                            from: 1.0
                            to: 0.3
                            duration: 800
                        }
                    }
                }

                Text {
                    text: "Place ball in zone"
                    font.pixelSize: 14
                    color: "#FF5722"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 40
                    visible: !ballDetected
                }
            }
        }

        // Coordinate display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#2D2D2D"
            radius: 9

            Text {
                anchors.centerIn: parent
                text: ballDetected
                      ? "X: " + (ballX * 100).toFixed(0) + "% | Y: " + (ballY * 100).toFixed(0) + "%"
                      : "Waiting for ball..."
                font.pixelSize: 14
                color: ballDetected ? "#4CAF50" : "#FF5722"
                font.bold: true
            }
        }
    }

    // Functions to update position from C++ backend
    function updateBallPosition(detected, normalizedX, normalizedY) {
        ballDetected = detected
        if (detected) {
            ballX = normalizedX
            ballY = normalizedY
        }
    }

    function show() {
        visible = true
    }

    function hide() {
        visible = false
    }
}
