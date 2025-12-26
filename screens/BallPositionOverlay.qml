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

                // 3D Golf Ball indicator with dimples
                Item {
                    id: ballIndicator
                    width: 35
                    height: 35

                    // Position based on normalized coordinates
                    x: (hitBox.width - width) * ballX
                    y: (hitBox.height - height) * ballY

                    visible: true

                    // Smooth movement animation (instant for real-time tracking)
                    Behavior on x {
                        NumberAnimation {
                            duration: 50  // Very fast for real-time
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 50
                            easing.type: Easing.OutQuad
                        }
                    }

                    // Main ball body with 3D gradient
                    Rectangle {
                        id: ballBody
                        anchors.fill: parent
                        radius: width / 2
                        color: ballDetected ? "#FFFFFF" : "transparent"
                        border.color: ballDetected ? "#4CAF50" : "#FF5722"
                        border.width: 2

                        // 3D lighting gradient
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ballDetected ? "#FFFFFF" : "transparent" }
                            GradientStop { position: 0.5; color: ballDetected ? "#F5F5F5" : "transparent" }
                            GradientStop { position: 1.0; color: ballDetected ? "#D0D0D0" : "transparent" }
                        }

                        // Top highlight (makes it look 3D)
                        Rectangle {
                            width: parent.width * 0.4
                            height: parent.height * 0.4
                            radius: width / 2
                            color: "#FFFFFF"
                            opacity: 0.7
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: parent.height * 0.15
                            anchors.leftMargin: parent.width * 0.15
                            visible: ballDetected
                        }

                        // Dimples (golf ball texture)
                        Repeater {
                            model: ballDetected ? 8 : 0

                            Rectangle {
                                property real angle: index * 45 * Math.PI / 180
                                property real distance: ballBody.width * 0.3

                                width: 3
                                height: 3
                                radius: 1.5
                                color: "#C0C0C0"
                                opacity: 0.5

                                x: ballBody.width / 2 + Math.cos(angle) * distance - width / 2
                                y: ballBody.height / 2 + Math.sin(angle) * distance - height / 2
                            }
                        }

                        // Center dimple
                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: "#B0B0B0"
                            opacity: 0.6
                            anchors.centerIn: parent
                            visible: ballDetected
                        }
                    }

                    // Subtle pulse when detected
                    SequentialAnimation on scale {
                        running: ballDetected
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1.0
                            to: 1.08
                            duration: 800
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 1.08
                            to: 1.0
                            duration: 800
                            easing.type: Easing.InOutQuad
                        }
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
