import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: windSettings
    width: 800
    height: 480

    property var win
    property real windSpeed: 10.0
    property real windDirection: 0.0

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
                    stack.goBack()
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: "Wind Settings"
                color: "#F0F6FC"
                font.pixelSize: 22
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            Item { implicitWidth: 90; implicitHeight: 42 }
        }

        Text {
            text: "Adjust wind conditions to simulate real-world effects on carry distance."
            color: "#8B949E"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Wind Speed ---
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
                    text: "Wind Speed: " + windSpeed.toFixed(1) + " mph"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                Slider {
                    id: speedSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 30
                    stepSize: 0.5
                    value: windSpeed
                    onValueChanged: windSpeed = value
                    
                    background: Rectangle {
                        x: speedSlider.leftPadding
                        y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: speedSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#30363D"

                        Rectangle {
                            width: speedSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#1F6FEB"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                        y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: speedSlider.pressed ? "#58A6FF" : "#1F6FEB"
                        border.color: "#F0F6FC"
                        border.width: 2
                    }
                }

                Text {
                    text: windSpeed < 5 ? "Light breeze" : windSpeed < 15 ? "Moderate wind" : windSpeed < 25 ? "Strong wind" : "Very strong wind"
                    color: "#A6D189"
                    font.pixelSize: 13
                }
            }
        }

        // --- Wind Direction ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            border.width: 2
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                Text {
                    text: "Wind Direction: " +
                          (windDirection < 0 ? "Headwind " : windDirection > 0 ? "Tailwind " : "Neutral ") +
                          "(" + windDirection.toFixed(0) + "°)"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                Slider {
                    id: directionSlider
                    Layout.fillWidth: true
                    from: -180
                    to: 180
                    stepSize: 5
                    value: windDirection
                    onValueChanged: windDirection = value
                    
                    background: Rectangle {
                        x: directionSlider.leftPadding
                        y: directionSlider.topPadding + directionSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: directionSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#30363D"

                        Rectangle {
                            width: directionSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#1F6FEB"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: directionSlider.leftPadding + directionSlider.visualPosition * (directionSlider.availableWidth - width)
                        y: directionSlider.topPadding + directionSlider.availableHeight / 2 - height / 2
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: directionSlider.pressed ? "#58A6FF" : "#1F6FEB"
                        border.color: "#F0F6FC"
                        border.width: 2
                    }
                }

                Text {
                    text: "← Headwind (adds distance) | Tailwind (reduces distance) →"
                    color: "#8B949E"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
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
                    while (stack.depth > 1) {
                        stack.pop()
                    }
                }
            }
        }
    }
}