import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage
    width: 800
    height: 480

    property var win

    // DARK THEME COLORS - MATCHING TEMPSETTINGS EXACTLY
    readonly property color bg: "#0D1117"
    readonly property color card: "#161B22"
    readonly property color edge: "#30363D"
    readonly property color text: "#F0F6FC"
    readonly property color hint: "#8B949E"
    readonly property color successText: "#A6D189"
    readonly property color accent: "#1F6FEB"
    readonly property color accentHover: "#1558B8"
    readonly property color success: "#238636"
    readonly property color successHover: "#1D6F2F"

    Rectangle {
        anchors.fill: parent
        color: bg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24
            
            // --- Header --- PERFECTLY CENTERED
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Button {
                    text: "← Back"
                    implicitWidth: 100
                    implicitHeight: 48
                    
                    background: Rectangle { 
                        color: parent.pressed ? successHover : success
                        radius: 6 
                    }
                    
                    contentItem: Text { 
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        
                        if (win) {
                            win.useWind = windToggle.checked
                            win.useTemp = tempToggle.checked
                            win.useBallType = ballToggle.checked
                            win.useLaunchEst = launchToggle.checked
                            win.useSimulateButton = simulateToggle.checked
                        }
                        
                        stack.goBack()
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: "Settings"
                    color: "#F0F6FC"
                    font.pixelSize: 24
                    font.bold: true
                }
                
                Item { Layout.fillWidth: true }
                
                Item {
                    implicitWidth: 100
                    implicitHeight: 48
                }
            }
            
            Text {
                text: "Enable or configure simulation effects:"
                font.pixelSize: 14
                color: hint
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Main Content
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 15

                    // WIND
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: windToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Wind Effects"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#F0F6FC"
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? accentHover : accent
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("WindSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // TEMPERATURE
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: tempToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Temperature Effects"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#F0F6FC"
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? accentHover : accent
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("TempSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // BALL TYPE
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: ballToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Ball Type"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#F0F6FC"
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? accentHover : accent
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("BallSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // LAUNCH SETTINGS
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: launchToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Launch Settings"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#F0F6FC"
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? accentHover : accent
                                    radius: 8
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    stack.push(Qt.resolvedUrl("LaunchSettings.qml"), { win: win })
                                }
                            }
                        }
                    }

                    // SIMULATE BUTTON
                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 15

                            Rectangle {
                                id: simulateToggle
                                property bool checked: false
                                
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 4
                                border.color: checked ? accent : edge
                                border.width: 2
                                color: checked ? accent : "transparent"
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                    visible: parent.checked
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        parent.checked = !parent.checked
                                    }
                                }
                            }

                            Text {
                                text: "Show Simulate Button"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#F0F6FC"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "On Metrics Page"
                                color: hint
                                font.pixelSize: 14
                                Layout.rightMargin: 10
                            }
                        }
                    }
                    
                    Item { height: 20 }
                }
            }
        }
    }
    
    Component.onCompleted: {
        if (win) {
            windToggle.checked = win.useWind || false
            tempToggle.checked = win.useTemp || false
            ballToggle.checked = win.useBallType || false
            launchToggle.checked = win.useLaunchEst || false
            simulateToggle.checked = win.useSimulateButton || false
        }
    }
}