import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: tempSettings
    width: 800
    height: 480

    property var win
    property real temperature: 72.0

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
                background: Rectangle { color: "#238636"; radius: 6 }
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
                color: "#F0F6FC"
                font.pixelSize: 22
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            Item { implicitWidth: 90; implicitHeight: 42 }
        }

        Text {
            text: "Adjust temperature to simulate real-world ball flight conditions."
            color: "#8B949E"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Temperature Slider ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            border.width: 2
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "Temperature: " + temperature.toFixed(1) + " °F"
                    color: "#F0F6FC"
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
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: tempSlider.pressed ? "#58A6FF" : "#1F6FEB"
                        border.color: "#F0F6FC"
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
                    color: "#A6D189"
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
            color: "#161B22"
            border.color: "#30363D"
            border.width: 2
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8

                Text {
                    text: "How Temperature Affects Different Balls:"
                    color: "#F0F6FC"
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "• Tour Balls: Most affected by cold\n• Mid Compression: Moderate sensitivity\n• Low Compression/Soft: Less affected\n• Range Balls: Minimal temperature effect"
                    color: "#8B949E"
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
                    color: parent.pressed ? "#1D6F2F" : "#238636"
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
                    color: parent.pressed ? "#1558B8" : "#1F6FEB"
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