import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsPage
    width: 800
    height: 480

    property var win

    // DARK THEME COLORS
    readonly property color bg: "#0D1117"
    readonly property color card: "#161B22"
    readonly property color edge: "#30363D"
    readonly property color text: "#F0F6FC"
    readonly property color hint: "#8B949E"
    readonly property color accent: "#1F6FEB"
    readonly property color success: "#238636"

    Rectangle {
        anchors.fill: parent
        color: bg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header Bar
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: card
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 0
                    
                    Button {
                        text: "← Back"
                        implicitHeight: 45
                        implicitWidth: 100
                        
                        background: Rectangle {
                            color: parent.pressed ? "#1D6F2F" : success
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
                    
                    Label {
                        text: "Settings"
                        color: text
                        font.pixelSize: 26
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Invisible spacer to balance the back button
                    Item {
                        implicitWidth: 100
                    }
                }
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
                    
                    Item { height: 20 }
                    
                    Label {
                        text: "Enable or configure simulation effects:"
                        font.pixelSize: 15
                        color: hint
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                    }

                    // WIND
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15

                            CheckBox {
                                id: windToggle
                                checked: false
                                
                                indicator: Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 4
                                    border.color: windToggle.checked ? accent : edge
                                    border.width: 2
                                    color: windToggle.checked ? accent : "transparent"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                        visible: windToggle.checked
                                    }
                                }
                            }

                            Label {
                                text: "Wind Effects"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? "#1558B8" : accent
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
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15

                            CheckBox { 
                                id: tempToggle
                                checked: false
                                
                                indicator: Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 4
                                    border.color: tempToggle.checked ? accent : edge
                                    border.width: 2
                                    color: tempToggle.checked ? accent : "transparent"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                        visible: tempToggle.checked
                                    }
                                }
                            }
                            
                            Label { 
                                text: "Temperature Effects"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true 
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? "#1558B8" : accent
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
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15

                            CheckBox { 
                                id: ballToggle
                                checked: false
                                
                                indicator: Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 4
                                    border.color: ballToggle.checked ? accent : edge
                                    border.width: 2
                                    color: ballToggle.checked ? accent : "transparent"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                        visible: ballToggle.checked
                                    }
                                }
                            }
                            
                            Label { 
                                text: "Ball Type"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true 
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? "#1558B8" : accent
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
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15

                            CheckBox { 
                                id: launchToggle
                                checked: false
                                
                                indicator: Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 4
                                    border.color: launchToggle.checked ? accent : edge
                                    border.width: 2
                                    color: launchToggle.checked ? accent : "transparent"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                        visible: launchToggle.checked
                                    }
                                }
                            }
                            
                            Label { 
                                text: "Launch Settings"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true 
                            }

                            Button {
                                text: "Configure"
                                implicitWidth: 110
                                implicitHeight: 50
                                
                                background: Rectangle { 
                                    color: parent.pressed ? "#1558B8" : accent
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
                        Layout.leftMargin: 24
                        Layout.rightMargin: 24
                        height: 80
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15

                            CheckBox { 
                                id: simulateToggle
                                checked: false
                                
                                indicator: Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 4
                                    border.color: simulateToggle.checked ? accent : edge
                                    border.width: 2
                                    color: simulateToggle.checked ? accent : "transparent"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                        visible: simulateToggle.checked
                                    }
                                }
                            }
                            
                            Label { 
                                text: "Show Simulate Button"
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                Layout.fillWidth: true 
                            }

                            Label {
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
            simulateToggle.checked = win.useSimulateButton !== undefined ? win.useSimulateButton : false
        }
    }
}