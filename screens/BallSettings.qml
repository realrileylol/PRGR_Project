import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: ballSettings
    width: 480
    height: 800

    property var win
    property string ballCompression: "Mid (80–90)"

    // Load current value when screen opens
    Component.onCompleted: {
        if (win) {
            ballCompression = win.ballCompression || "Mid (80–90)"
            // Set the combobox to match
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
                text: "Ball Settings"
                color: "#F0F6FC"
                font.pixelSize: 24
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Ball compression affects how the ball reacts to club impact. Softer balls compress more easily, while firmer balls transfer energy more efficiently."
            color: "#8B949E"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // --- Compression Selection ---
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
                    text: "Ball Compression:"
                    color: "#F0F6FC"
                    font.pixelSize: 22
                    font.bold: true
                }

                ComboBox {
                    id: compressionSelect
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    
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
                        color: "#1C2128"
                        radius: 8
                        border.color: compressionSelect.pressed ? "#58A6FF" : "#30363D"
                        border.width: 2
                    }

                    contentItem: Text {
                        leftPadding: 15
                        text: compressionSelect.displayText
                        font.pixelSize: 16
                        color: "#F0F6FC"
                        verticalAlignment: Text.AlignVCenter
                    }

                    delegate: ItemDelegate {
                        width: compressionSelect.width
                        height: 50
                        
                        contentItem: Text {
                            text: modelData
                            color: "#F0F6FC"
                            font.pixelSize: 15
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 15
                        }
                        
                        background: Rectangle {
                            color: parent.highlighted ? "#1F6FEB" : "#1C2128"
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
                            color: "#1C2128"
                            border.color: "#30363D"
                            border.width: 2
                            radius: 8
                        }
                    }
                }

                Label {
                    text: "Selected: " + ballCompression.split(' – ')[0]
                    color: "#A6D189"
                    font.pixelSize: 16
                    font.bold: true
                }
            }
        }

        // --- How Compression Affects Performance ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Label {
                    text: "How Compression Affects Your Shots:"
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }

                // Low Compression
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 6
                    color: "#0D1117"
                    
                    Label {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "🟢 Low (<70): Higher launch, less spin, best for slower swing speeds"
                        color: "#8B949E"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Mid Compression
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 6
                    color: "#0D1117"
                    
                    Label {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "🟡 Mid (80-90): Balanced performance, most versatile"
                        color: "#8B949E"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // High Compression
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 6
                    color: "#0D1117"
                    
                    Label {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "🔴 High (90+): Lower launch, more spin, best for faster swing speeds"
                        color: "#8B949E"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Range Ball
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 6
                    color: "#0D1117"
                    
                    Label {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "⚪ Range: Very firm, durable, less temperature sensitivity"
                        color: "#8B949E"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
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
                        win.ballCompression = ballCompression
                        console.log("Saved ball compression:", ballCompression)
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
                        win.ballCompression = ballCompression
                        console.log("Saved ball compression:", ballCompression)
                    }
                    // Go back to main screen
                    while (stack.depth > 1) {
                        stack.pop()
                    }
                }
            }
        }
    }
}