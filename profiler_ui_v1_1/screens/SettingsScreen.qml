import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Page {
    id: settingsPage
    title: "Settings"

    Rectangle {
        anchors.fill: parent
        color: "#F4F6FA" // light gray background for contrast

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 24
            width: parent.width * 0.9

            // Title
            Text {
                text: "⚙️ Settings"
                font.pixelSize: 32
                font.bold: true
                color: "#1C1C1C"
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Enable or configure simulation effects below:"
                font.pixelSize: 16
                color: "#3A3A3A"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.alignment: Qt.AlignHCenter
            }

            // ---- WIND ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                CheckBox {
                    id: windToggle
                    text: "Wind Effects"
                    checked: false
                    font.pixelSize: 18
                    Layout.fillWidth: true
    
                }

                Button {
                    text: "\u2699"
                    width: 45
                    height: 45
                    font.pixelSize: 20
                    background: Rectangle {
                        color: "#4A90E2"
                        radius: 10
                    }
                    onClicked: stack.push(Qt.resolvedUrl("screens/WindSettings.qml"))
                }
            }

            // ---- TEMPERATURE ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                CheckBox {
                    id: tempToggle
                    text: "Temperature Effects"
                    checked: false
                    font.pixelSize: 18
                    Layout.fillWidth: true
                
                }

                Button {
                    text: "\u2699"
                    width: 45
                    height: 45
                    font.pixelSize: 20
                    background: Rectangle {
                        color: "#4A90E2"
                        radius: 10
                    }
                    onClicked: stack.push(Qt.resolvedUrl("screens/TempSettings.qml"))
                }
            }

            // ---- BALL ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                CheckBox {
                    id: ballToggle
                    text: "Ball Type"
                    checked: false
                    font.pixelSize: 18
                    Layout.fillWidth: true
                    
                }

                Button {
                    text: "\u2699"
                    width: 45
                    height: 45
                    font.pixelSize: 20
                    background: Rectangle {
                        color: "#4A90E2"
                        radius: 10
                    }
                    onClicked: stack.push(Qt.resolvedUrl("screens/BallSettings.qml"))
                }
            }

            // ---- LAUNCH ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                CheckBox {
                    id: launchToggle
                    text: "Launch Settings"
                    checked: false
                    font.pixelSize: 18
                    Layout.fillWidth: true
                    
                }

                Button {
                    text: "\u2699"
                    width: 45
                    height: 45
                    font.pixelSize: 20
                    background: Rectangle {
                        color: "#4A90E2"
                        radius: 10
                    }
                    onClicked: stack.push(Qt.resolvedUrl("screens/LaunchSettings.qml"))
                }
            }

            // --- Back Button ---
            Button {
                text: "⬅ Back to Main"
                font.pixelSize: 18
                width: parent.width * 0.6
                height: 50
                anchors.horizontalCenter: parent.horizontalCenter
                background: Rectangle {
                    color: "#4A90E2"
                    radius: 10
                }
                Button {
    text: "💾 Save & Return"
    Layout.alignment: Qt.AlignHCenter
    width: parent.width * 0.6
    height: 40

    background: Rectangle {
        radius: 10
        color: "#4A90E2"
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
        // Save each toggle into root.win (or global settings object)
        if (win) {
            win.windEnabled = windToggle.checked
            win.tempEnabled = tempToggle.checked
            win.ballEnabled = ballToggle.checked
            win.launchEnabled = launchToggle.checked
        }

        // Go back to main screen
        stack.goBack()
    }
}

                onClicked: stack.pop()
            }
        }
    }
}
