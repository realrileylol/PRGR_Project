import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: launchSettings
    width: 800
    height: 480

    property var win
    property real baseLaunchAngle: 16.0
    property real launchVariance: 2.0

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

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Back"
                implicitWidth: 90
                implicitHeight: 42
                background: Rectangle { color: success; radius: 6 }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    soundManager.playClick()
                    stack.goBack()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Launch Angle Settings - ONLY USE IF CAMERA NOT WORKING"
                color: text
                font.pixelSize: 22
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Item { implicitWidth: 90; implicitHeight: 42 }
        }

        Text {
            text: "Set your baseline launch angle and variation for realistic results."
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

        // --- Baseline Launch Angle ---
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
                    text: "Baseline Launch Angle: " + baseLaunchAngle.toFixed(1) + "°"
                    color: text
                    font.pixelSize: 20
                    font.bold: true
                }

                Slider {
                    id: baseSlider
                    Layout.fillWidth: true
                    from: 8
                    to: 22
                    stepSize: 0.1
                    value: baseLaunchAngle
                    onValueChanged: baseLaunchAngle = value
                    
                    background: Rectangle {
                        x: baseSlider.leftPadding
                        y: baseSlider.topPadding + baseSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: baseSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: edge

                        Rectangle {
                            width: baseSlider.visualPosition * parent.width
                            height: parent.height
                            color: accent
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: baseSlider.leftPadding + baseSlider.visualPosition * (baseSlider.availableWidth - width)
                        y: baseSlider.topPadding + baseSlider.availableHeight / 2 - height / 2
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: baseSlider.pressed ? "#2563EB" : accent
                        border.color: text
                        border.width: 2
                    }
                }

                Text {
                    text: {
                        if (baseLaunchAngle < 12) return "Low Launch – More Roll, Less Carry"
                        else if (baseLaunchAngle < 17) return "Mid Launch – Balanced Carry & Roll"
                        else return "High Launch – Max Carry, Less Roll"
                    }
                    color: "#2D9A4F"
                    font.pixelSize: 13
                }
            }
        }

        // --- Launch Variance ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "Launch Variance: ±" + launchVariance.toFixed(1) + "°"
                    color: text
                    font.pixelSize: 20
                    font.bold: true
                }

                Slider {
                    id: varianceSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 4
                    stepSize: 0.1
                    value: launchVariance
                    onValueChanged: launchVariance = value
                    
                    background: Rectangle {
                        x: varianceSlider.leftPadding
                        y: varianceSlider.topPadding + varianceSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: varianceSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: edge

                        Rectangle {
                            width: varianceSlider.visualPosition * parent.width
                            height: parent.height
                            color: accent
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: varianceSlider.leftPadding + varianceSlider.visualPosition * (varianceSlider.availableWidth - width)
                        y: varianceSlider.topPadding + varianceSlider.availableHeight / 2 - height / 2
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: varianceSlider.pressed ? "#2563EB" : accent
                        border.color: text
                        border.width: 2
                    }
                }

                Text {
                    text: "Higher variance = less consistent but more realistic"
                    color: hint
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
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
                text: "Save & Return"
                Layout.fillWidth: true
                implicitHeight: 48
                
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
                
                onClicked: {
                    soundManager.playClick()
                    stack.goBack()
                }
            }

            Button {
                text: "Save & Home"
                Layout.fillWidth: true
                implicitHeight: 48
                
                background: Rectangle {
                    color: parent.pressed ? "#2563EB" : accent
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
                
                onClicked: {
                    soundManager.playClick()
                    while (stack.depth > 1) {
                        stack.pop()
                    }
                }
            }
        }
    }
}