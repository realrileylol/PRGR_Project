import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: ballSettings
    width: 800
    height: 480

    property var win
    property string ballCompression: "Mid (80–90)"

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
            ballCompression = win.ballCompression || "Mid (80–90)"
            for (var i = 0; i < compressionSelect.model.length; i++) {
                if (compressionSelect.model[i].includes(ballCompression.split(' ')[0])) {
                    compressionSelect.currentIndex = i
                    break
                }
            }
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
                text: "Ball Settings"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            Item { implicitWidth: 90; implicitHeight: 42 }
        }

        Text {
            text: "Ball compression affects how the ball reacts to club impact."
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

        // --- Compression Selection ---
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
                spacing: 12

                Text {
                    text: "Ball Compression:"
                    color: text
                    font.pixelSize: 18
                    font.bold: true
                }

                ComboBox {
                    id: compressionSelect
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    
                    model: [
                        "Low (<70) – Soft / High Launch / Low Spin",
                        "Mid (80–90) – Balanced / Tour-Like",
                        "High (90+) – Firm / High Spin / Lower Launch",
                        "Range – Very Firm / Durable / Distance"
                    ]
                    
                    currentIndex: 1
                    
                    onCurrentTextChanged: {
                        ballCompression = currentText
                    }

                    background: Rectangle {
                        color: "#F5F7FA"
                        radius: 8
                        border.color: compressionSelect.pressed ? accent : edge
                        border.width: 2
                    }

                    contentItem: Text {
                        leftPadding: 12
                        text: compressionSelect.displayText
                        font.pixelSize: 14
                        color: text
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    delegate: ItemDelegate {
                        width: compressionSelect.width
                        height: 45
                        
                        contentItem: Text {
                            text: modelData
                            color: text
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 12
                        }

                        background: Rectangle {
                            color: parent.highlighted ? "#E8F0FE" : "white"
                        }
                    }

                    popup: Popup {
                        y: compressionSelect.height + 5
                        width: compressionSelect.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 1

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: compressionSelect.popup.visible ? compressionSelect.delegateModel : null
                            currentIndex: compressionSelect.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }

                        background: Rectangle {
                            color: card
                            border.color: edge
                            border.width: 2
                            radius: 8
                        }
                    }
                }
            }
        }

        // --- How Compression Affects Performance ---
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
                spacing: 8

                Text {
                    text: "How Compression Affects Your Shots:"
                    color: text
                    font.pixelSize: 16
                    font.bold: true
                }

                ColumnLayout {
                    spacing: 6
                    Layout.fillWidth: true
                    
                    Text {
                        text: "🟢 Low (<70): Higher launch, less spin, slower swing speeds"
                        color: hint
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: "🟡 Mid (80-90): Balanced performance, most versatile"
                        color: hint
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: "🔴 High (90+): Lower launch, more spin, faster swing speeds"
                        color: hint
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: "⚪ Range: Very firm, durable, less temperature sensitivity"
                        color: hint
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
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
                    if (win) {
                        win.ballCompression = ballCompression
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
                        win.ballCompression = ballCompression
                    }
                    while (stack.depth > 1) {
                        stack.pop()
                    }
                }
            }
        }
    }
}