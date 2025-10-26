import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage
    // let parent/window size drive it (works for 480x320)
    anchors.fill: parent

    property var win

    Rectangle {
        anchors.fill: parent
        color: "#F5F7FA"

        // NEW: make the page scrollable
        ScrollView {
            id: scroller
            anchors.fill: parent
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            // IMPORTANT: keep content width equal to viewport width
            contentItem: ColumnLayout {
                id: content
                width: scroller.width
                anchors.margins: 24
                spacing: 20

                // --- Header ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Label {
                        text: "⚙️ Settings"
                        font.pixelSize: 28
                        font.bold: true
                        color: "#1C1C1C"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Label {
                    text: "Enable or configure simulation effects below:"
                    font.pixelSize: 16
                    color: "#3A3A3A"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.preferredHeight: 20 }

                // ---- WIND ----
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    radius: 10
                    color: "white"
                    border.color: "#D0D5DD"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 15

                        CheckBox {
                            id: windToggle
                            checked: win ? win.useWind : false
                        }

                        Label {
                            text: "Wind Effects"
                            font.pixelSize: 18
                            color: "#1C1C1C"
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "⚙"
                            implicitWidth: 60
                            implicitHeight: 60
                            background: Rectangle { color: parent.pressed ? "#3A7BC8" : "#4A90E2"; radius: 10 }
                            contentItem: Text {
                                text: parent.text; color: "white"; font.pixelSize: 24
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                soundManager.playClick()
                                stack.push(Qt.resolvedUrl("WindSettings.qml"), { win: win })
                            }
                        }
                    }
                }

                // ---- TEMPERATURE ----
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    radius: 10
                    color: "white"
                    border.color: "#D0D5DD"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 15

                        CheckBox { id: tempToggle; checked: win ? win.useTemp : false }
                        Label { text: "Temperature Effects"; font.pixelSize: 18; color: "#1C1C1C"; Layout.fillWidth: true }

                        Button {
                            text: "⚙"; implicitWidth: 60; implicitHeight: 60
                            background: Rectangle { color: parent.pressed ? "#3A7BC8" : "#4A90E2"; radius: 10 }
                            contentItem: Text {
                                text: parent.text; color: "white"; font.pixelSize: 24
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                soundManager.playClick()
                                stack.push(Qt.resolvedUrl("TempSettings.qml"), { win: win })
                            }
                        }
                    }
                }

                // ---- BALL TYPE ----
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    radius: 10
                    color: "white"
                    border.color: "#D0D5DD"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 15

                        CheckBox { id: ballToggle; checked: win ? win.useBallType : false }
                        Label { text: "Ball Type"; font.pixelSize: 18; color: "#1C1C1C"; Layout.fillWidth: true }

                        Button {
                            text: "⚙"; implicitWidth: 60; implicitHeight: 60
                            background: Rectangle { color: parent.pressed ? "#3A7BC8" : "#4A90E2"; radius: 10 }
                            contentItem: Text {
                                text: parent.text; color: "white"; font.pixelSize: 24
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                soundManager.playClick()
                                stack.push(Qt.resolvedUrl("BallSettings.qml"), { win: win })
                            }
                        }
                    }
                }

                // ---- LAUNCH SETTINGS ----
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    radius: 10
                    color: "white"
                    border.color: "#D0D5DD"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 15

                        CheckBox { id: launchToggle; checked: win ? win.useLaunchEst : true }
                        Label { text: "Launch Settings"; font.pixelSize: 18; color: "#1C1C1C"; Layout.fillWidth: true }

                        Button {
                            text: "⚙"; implicitWidth: 60; implicitHeight: 60
                            background: Rectangle { color: parent.pressed ? "#3A7BC8" : "#4A90E2"; radius: 10 }
                            contentItem: Text {
                                text: parent.text; color: "white"; font.pixelSize: 24
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                soundManager.playClick()
                                stack.push(Qt.resolvedUrl("LaunchSettings.qml"), { win: win })
                            }
                        }
                    }
                }

                // Small spacer (don’t use Layout.fillHeight inside a ScrollView)
                Item { height: 12 }

                // --- Save & Return Button ---
                Button {
                    text: "💾 Save & Return"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    implicitHeight: 56
                    background: Rectangle { color: parent.pressed ? "#3A7BC8" : "#4A90E2"; radius: 12 }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 18; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        soundManager.playClick()
                        if (win) {
                            win.useWind = windToggle.checked
                            win.useTemp = tempToggle.checked
                            win.useBallType = ballToggle.checked
                            win.useLaunchEst = launchToggle.checked
                        }
                        stack.goBack()
                    }
                }
            }
        }
    }
}
