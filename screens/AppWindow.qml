import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 480
    height: 800

    property var win

    // Theme colors
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color ok: "#34C759"

    Rectangle { anchors.fill: parent; color: bg }

    // ---------- Carry & Total Calculation ----------
    function estimateCarry7i(clubSpeed, spinRpm) {
        const baseCS = 92.0
        const baseCarry = 182.0
        const speedExp = 1.045
        var carry = baseCarry * Math.pow(clubSpeed / baseCS, speedExp)
        carry += (6500 - spinRpm) * 0.006
        return Math.round(carry)
    }

    function estimateTotal(carryYd, turf) {
        var roll = (turf === "firm") ? 14 : (turf === "soft") ? 7 : 10
        return carryYd + roll
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ---------- Top Bar ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Label {
                id: profileLabel
                text: "👤 " + (win ? win.activeProfile : "Guest")
                color: text
                font.pixelSize: 20
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "Profile"
                implicitWidth: 110
                implicitHeight: 56
                
                background: Rectangle {
                    color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                    radius: 10
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#1A1D23"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: { 
                    soundManager.playClick()
                    stack.openProfile()
                }
            }
            
            Button {
                text: "Settings"
                implicitWidth: 110
                implicitHeight: 56
                
                background: Rectangle {
                    color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                    radius: 10
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#1A1D23"
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    soundManager.playClick()
                    stack.openSettings()
                }
            }
        }

        // ---------- Club & Ball Selector ----------
        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: card
            border.color: edge
            border.width: 2
            height: 85
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Label {
                        text: "CLUB"
                        color: hint
                        font.pixelSize: 12
                        font.bold: true
                    }
                    
                    ComboBox {
                        id: clubSelector
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        
                        model: win ? Object.keys(win.activeClubBag || {}) : []
                        currentIndex: 7
                        
                        Component.onCompleted: {
                            if (win && win.currentClub && model.length > 0) {
                                var idx = model.indexOf(win.currentClub)
                                if (idx >= 0) currentIndex = idx
                            }
                        }
                        
                        onCurrentTextChanged: {
                            if (win && win.activeClubBag && currentText) {
                                win.currentClub = currentText
                                win.currentLoft = win.activeClubBag[currentText] || 34.0
                                soundManager.playClick()
                            }
                        }
                        
                        background: Rectangle {
                            color: "#F5F7FA"
                            radius: 8
                            border.color: clubSelector.pressed ? accent : "#E5E7EB"
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            leftPadding: 10
                            text: {
                                if (win && win.activeClubBag && clubSelector.displayText) {
                                    return clubSelector.displayText + " (" + 
                                           (win.activeClubBag[clubSelector.displayText] || 0).toFixed(1) + "°)"
                                }
                                return clubSelector.displayText
                            }
                            font.pixelSize: 16
                            font.bold: true
                            color: text
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        delegate: ItemDelegate {
                            width: clubSelector.width
                            height: 45
                            
                            contentItem: Text {
                                text: {
                                    if (win && win.activeClubBag) {
                                        return modelData + " (" + (win.activeClubBag[modelData] || 0).toFixed(1) + "°)"
                                    }
                                    return modelData
                                }
                                color: text
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#E8F0FE" : "white"
                            }
                        }
                        
                        popup: Popup {
                            y: clubSelector.height + 2
                            width: clubSelector.width
                            implicitHeight: Math.min(400, contentItem.implicitHeight)
                            padding: 1
                            
                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: clubSelector.popup.visible ? clubSelector.delegateModel : null
                                currentIndex: clubSelector.highlightedIndex
                                ScrollIndicator.vertical: ScrollIndicator { }
                            }
                            
                            background: Rectangle {
                                color: "white"
                                border.color: edge
                                border.width: 2
                                radius: 8
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    color: edge
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "BALL"
                        color: hint
                        font.pixelSize: 12
                        font.bold: true
                    }
                    
                    Label {
                        text: {
                            if (win && win.ballCompression) {
                                return win.ballCompression.split(' –')[0]
                            }
                            return "Mid (80-90)"
                        }
                        color: text
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
                
                Button {
                    text: "⚙"
                    implicitWidth: 50
                    implicitHeight: 50
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: text
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        stack.push(Qt.resolvedUrl("MyBag.qml"), { win: win })
                    }
                }
            }
        }

        // ---------- Metrics ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: card
            border.color: edge
            border.width: 2

            GridLayout {
                anchors.fill: parent
                anchors.margins: 20
                columns: 2
                columnSpacing: 20
                rowSpacing: 18

                // BALL SPEED
                ColumnLayout {
                    spacing: 4
                    Label { 
                        text: "BALL SPEED"
                        color: hint
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Label { 
                        text: (win ? win.ballSpeed.toFixed(1) : "0.0") + " mph"
                        color: text
                        font.pixelSize: 38
                        font.bold: true
                    }
                }

                // CLUB SPEED
                ColumnLayout {
                    spacing: 4
                    Label { 
                        text: "CLUB SPEED"
                        color: hint
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Label { 
                        text: (win ? win.clubSpeed.toFixed(1) : "0.0") + " mph"
                        color: text
                        font.pixelSize: 38
                        font.bold: true
                    }
                }

                // LAUNCH ANGLE
                ColumnLayout {
                    spacing: 4
                    Label { 
                        text: "LAUNCH ANGLE"
                        color: hint
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Label { 
                        text: (win ? win.launchDeg.toFixed(1) : "0.0") + "°"
                        color: text
                        font.pixelSize: 38
                        font.bold: true
                    }
                }

                // SPIN RATE
                ColumnLayout {
                    spacing: 4
                    Label { 
                        text: "SPIN RATE"
                        color: hint
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Label { 
                        text: (win ? win.spinEst : 0) + " rpm"
                        color: text
                        font.pixelSize: 38
                        font.bold: true
                    }
                }

                // SMASH FACTOR
                ColumnLayout {
                    spacing: 4
                    Label { 
                        text: "SMASH FACTOR"
                        color: hint
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Label { 
                        text: (win ? win.smash.toFixed(2) : "0.00")
                        color: text
                        font.pixelSize: 38
                        font.bold: true
                    }
                }

                // CARRY
                ColumnLayout {
                    spacing: 4
                    Label { 
                        text: "CARRY"
                        color: hint
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Label { 
                        text: (win ? win.carry : 0) + " yd"
                        color: text
                        font.pixelSize: 38
                        font.bold: true
                    }
                }
            }
        }

        // ---------- Simulate Shot ----------
        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            height: 64
            text: "SIMULATE SHOT"
            
            scale: pressed ? 0.97 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
            
            background: Rectangle { 
                color: parent.pressed ? "#2563EB" : accent
                radius: 14
            }
            
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                if (!win) return
                
                soundManager.playClick()

                function rand(min, max) { return min + Math.random() * (max - min) }

                win.clubSpeed = rand(90, 96)
                win.smash = rand(1.37, 1.41)
                win.ballSpeed = win.clubSpeed * win.smash
                win.spinEst = Math.round(rand(5800, 6700))
                win.launchDeg = rand(14, 18)

                var carryCalc = estimateCarry7i(win.clubSpeed, win.spinEst)
                
                if (win.useTemp && win.temperature) {
                    var temp = win.temperature
                    var tempDiff = temp - 75.0
                    var tempEffect = 0
                    
                    if (temp < 50) {
                        tempEffect = tempDiff * 0.35
                    } else if (temp < 65) {
                        tempEffect = tempDiff * 0.20
                    } else if (temp < 85) {
                        tempEffect = tempDiff * 0.10
                    } else {
                        tempEffect = tempDiff * 0.15
                    }
                    
                    var compressionMod = 1.0
                    if (win.useBallType && win.ballCompression) {
                        var comp = win.ballCompression.toLowerCase()
                        if (comp.includes("low") || comp.includes("soft")) {
                            compressionMod = 0.7
                        } else if (comp.includes("mid")) {
                            compressionMod = 1.0
                        } else if (comp.includes("high") || comp.includes("firm")) {
                            compressionMod = 1.3
                        } else if (comp.includes("range")) {
                            compressionMod = 0.5
                        }
                    }
                    
                    carryCalc += (tempEffect * compressionMod)
                }
                
                win.carry = Math.max(0, Math.round(carryCalc))
                win.total = estimateTotal(win.carry, "normal")
                
                soundManager.playSuccess()
            }
        }

        // ---------- Status Line ----------
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 10
            color: "#E9F5E9"
            border.color: "#C6E6C3"
            border.width: 2
            
            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                
                Rectangle { 
                    width: 12
                    height: 12
                    radius: 6
                    color: ok
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Label { 
                    text: "Ready to capture next shot…"
                    color: "#1A5D1A"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}