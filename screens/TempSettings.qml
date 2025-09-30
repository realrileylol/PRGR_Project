import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: tempSettings
    width: 480
    height: 800

    property var win
    property real temperature: 72.0

    // Load current value when screen opens
    Component.onCompleted: {
        if (win) {
            temperature = win.temperature || 72.0
        }
    }

    Rectangle { 
        anchors.fill: parent
        color: "#0D1117" 
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Button {
                text: "← Back"
                implicitWidth: 100
                implicitHeight: 48
                background: Rectangle { color: "#238636"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16 }
                onClicked: {
                    soundManager.playClick()
                    stack.goBack()
                }
            }
            Label {
                text: "Temperature Settings"
                color: "#F0F6FC"
                font.pixelSize: 24
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Adjust temperature to simulate real-world ball flight conditions. Temperature affects air density, ball compression, and carry distance."
            color: "#8B949E"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Temperature Slider ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Label {
                    text: "Temperature: " + temperature.toFixed(1) + " °F"
                    color: "#F0F6FC"
                    font.pixelSize: 28
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
                        color: "#30363D"

                        Rectangle {
                            width: tempSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#1F6FEB"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                        y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: tempSlider.pressed ? "#58A6FF" : "#1F6FEB"
                        border.color: "#F0F6FC"
                        border.width: 2
                    }
                }

                Label {
                    text: {
                        if (temperature < 50) return "❄️ Cold – Ball loses ~2-5 yards per 10°F"
                        else if (temperature < 65) return "🌤️ Cool – Ball loses ~1-2 yards per 10°F"
                        else if (temperature < 85) return "☀️ Ideal – Standard conditions (75°F baseline)"
                        else return "🔥 Hot – Ball gains ~1-2 yards per 10°F"
                    }
                    color: "#A6D189"
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // --- Ball Compression Info ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                Label {
                    text: "How Temperature Affects Different Balls:"
                    color: "#F0F6FC"
                    font.pixelSize: 18
                    font.bold: true
                }

                Label {
                    text: "• Tour Balls (High Compression): Most affected by cold\n• Mid Compression: Moderate temperature sensitivity\n• Low Compression/Soft: Less affected by temperature\n• Range Balls: Minimal temperature effect (harder core)"
                    color: "#8B949E"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // Spacer
        Item { Layout.fillHeight: true }

        // --- Buttons ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Button {
                text: "Save & Return"
                Layout.fillWidth: true
                implicitHeight: 56
                
                background: Rectangle { 
                    color: parent.pressed ? "#1D6F2F" : "#238636"
                    radius: 8 
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
                    // SAVE TO WIN
                    if (win) {
                        win.temperature = temperature
                        console.log("Saved temperature:", temperature)
                    }
                    stack.goBack()
                }
            }

            Button {
                text: "Save & Home"
                Layout.fillWidth: true
                implicitHeight: 56
                
                background: Rectangle { 
                    color: parent.pressed ? "#1558B8" : "#1F6FEB"
                    radius: 8 
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
                    // SAVE TO WIN
                    if (win) {
                        win.temperature = temperature
                        console.log("Saved temperature:", temperature)
                    }
                    // Go back to main screen (pop all)
                    while (stack.depth > 1) {
                        stack.pop()
                    }
                }
            }
        }
    }
}