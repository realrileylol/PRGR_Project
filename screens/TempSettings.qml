import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: tempSettings
    width: 800
    height: 480

    property var win
    property real temperature: 72.0

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
        if (win) {
            temperature = win.temperature || 72.0
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
                text: "← Back"
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
                    if (win) {
                        win.temperature = temperature
                    }
                    stack.goBack()
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: "Temperature Settings"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            Item { implicitWidth: 90; implicitHeight: 42 }
        }

        Text {
            text: "Adjust temperature to simulate real-world ball flight conditions."
            color: hint
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Temperature Slider ---
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
                    text: "Temperature: " + temperature.toFixed(1) + " °F"
                    color: text
                    font.pixelSize: 22
                    font.bold: true
                }

                Slider {
                    id: tempSlider
                    Layout.fillWidth: true
                    from: 32
                    to: 105
                    stepSize: 1
                    value: temperature
                    
                    onValueChanged: {
                        temperature = value
                    }
                    
                    background: Rectangle {
                        x: tempSlider.leftPadding
                        y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: tempSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: edge

                        Rectangle {
                            width: tempSlider.visualPosition * parent.width
                            height: parent.height
                            color: accent
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                        y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: tempSlider.pressed ? "#2563EB" : accent
                        border.color: text
                        border.width: 2
                    }
                }

                Text {
                    text: {
                        if (temperature < 50) return "❄️ Cold – Ball loses ~2-5 yards per 10°F"
                        else if (temperature < 65) return "🌤️ Cool – Ball loses ~1-2 yards per 10°F"
                        else if (temperature < 85) return "☀️ Ideal – Standard conditions (75°F baseline)"
                        else return "🔥 Hot – Ball gains ~1-2 yards per 10°F"
                    }
                    color: "#2D9A4F"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // --- Ball Compression Info ---
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
                spacing: 8

                Text {
                    text: "How Temperature Affects Different Balls:"
                    color: text
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "• Tour Balls: Most affected by cold\n• Mid Compression: Moderate sensitivity\n• Low Compression/Soft: Less affected\n• Range Balls: Minimal temperature effect"
                    color: hint
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    lineHeight: 1.3
                }
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
                    if (win) {
                        win.temperature = temperature
                    }
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
                    if (win) {
                        win.temperature = temperature
                    }
                    while (stack.depth > 1) {
                        stack.pop()
                    }
                }
            }
        }
    }
}