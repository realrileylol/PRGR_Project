import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 800
    height: 480

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

    // ---------- Calculations ----------
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

    // Page indicator dots
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 12
        spacing: 12
        z: 100
        
        Repeater {
            model: 2
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: swipeView.currentIndex === index ? accent : "#C8CCD4"
                
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }

    SwipeView {
        id: swipeView
        anchors.fill: parent
        currentIndex: 0

        // ========== PAGE 1: CONTROLS ==========
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                // Top Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Label {
                        id: profileLabel
                        text: "👤 " + (win ? win.activeProfile : "Guest")
                        color: text
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    
                    Label {
                        text: "Swipe for metrics →"
                        color: hint
                        font.pixelSize: 14
                        font.italic: true
                    }
                }
                
                // Profile/Settings buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Button {
                        text: "Profile"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        
                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                            radius: 12
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#1A1D23"
                            font.pixelSize: 18
                            font.bold: true
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
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        
                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                            radius: 12
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#1A1D23"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            soundManager.playClick()
                            stack.openSettings()
                        }
                    }
                }

                // Club Selector
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: card
                    border.color: edge
                    border.width: 2
                    Layout.fillHeight: true
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        Label {
                            text: "CLUB SELECTION"
                            color: hint
                            font.pixelSize: 13
                            font.bold: true
                        }
                        
                        ComboBox {
                            id: clubSelector
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            
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
                                radius: 10
                                border.color: clubSelector.pressed ? accent : "#E5E7EB"
                                border.width: 2
                            }
                            
                            contentItem: Text {
                                leftPadding: 16
                                text: {
                                    if (win && win.activeClubBag && clubSelector.displayText) {
                                        return clubSelector.displayText + " (" + 
                                               (win.activeClubBag[clubSelector.displayText] || 0).toFixed(1) + "°)"
                                    }
                                    return clubSelector.displayText
                                }
                                font.pixelSize: 18
                                font.bold: true
                                color: text
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            
                            delegate: ItemDelegate {
                                width: clubSelector.width
                                height: 56
                                
                                contentItem: Text {
                                    text: {
                                        if (win && win.activeClubBag) {
                                            return modelData + " (" + (win.activeClubBag[modelData] || 0).toFixed(1) + "°)"
                                        }
                                        return modelData
                                    }
                                    color: text
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 16
                                }
                                
                                background: Rectangle {
                                    color: parent.highlighted ? "#E8F0FE" : "white"
                                }
                            }
                            
                            popup: Popup {
                                y: clubSelector.height + 4
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
                                    radius: 10
                                }
                            }
                        }
                        
                        Button {
                            text: "⚙ Edit Bag"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            
                            background: Rectangle {
                                color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                                radius: 10
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: text
                                font.pixelSize: 15
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                soundManager.playClick()
                                stack.push(Qt.resolvedUrl("MyBag.qml"), { win: win })
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }

                // SIMULATE SHOT BUTTON (replaces quick stats)
                Button {
                    Layout.fillWidth: true
                    height: 80
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
                        font.pixelSize: 22
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
                        
                        // Auto-swipe to metrics page to see results
                        swipeView.currentIndex = 1
                    }
                }

                // Status
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
                            width: 14
                            height: 14
                            radius: 7
                            color: ok
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Label { 
                            text: "Ready"
                            color: "#1A5D1A"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ========== PAGE 2: METRICS ONLY ==========
        Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                radius: 14
                color: card
                border.color: edge
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 50
                        color: accent
                        radius: 14
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            
                            Label {
                                text: "← Swipe back"
                                color: "white"
                                font.pixelSize: 13
                                opacity: 0.85
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Label {
                                text: "SHOT METRICS"
                                color: "white"
                                font.pixelSize: 20
                                font.bold: true
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Label {
                                text: (win ? win.currentClub : "7 Iron")
                                color: "white"
                                font.pixelSize: 13
                                opacity: 0.85
                            }
                        }
                    }

                    // Metrics Grid
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 14
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                        columns: 2
                        rows: 4
                        columnSpacing: 12
                        rowSpacing: 10

                        // BALL SPEED
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#F5F7FA"
                            border.color: edge
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "BALL SPEED"
                                    color: hint
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.ballSpeed.toFixed(1) : "0.0")
                                    color: text
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "mph"
                                    color: hint
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // CLUB SPEED
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#F5F7FA"
                            border.color: edge
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "CLUB SPEED"
                                    color: hint
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.clubSpeed.toFixed(1) : "0.0")
                                    color: text
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "mph"
                                    color: hint
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // LAUNCH
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#F5F7FA"
                            border.color: edge
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "LAUNCH"
                                    color: hint
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.launchDeg.toFixed(1) : "0.0")
                                    color: text
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "degrees"
                                    color: hint
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // SPIN
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#F5F7FA"
                            border.color: edge
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "SPIN"
                                    color: hint
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.spinEst : 0)
                                    color: text
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "rpm"
                                    color: hint
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // SMASH
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#F5F7FA"
                            border.color: edge
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "SMASH"
                                    color: hint
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.smash.toFixed(2) : "0.00")
                                    color: text
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "factor"
                                    color: hint
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // CARRY
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#FFF8E1"
                            border.color: "#FFD54F"
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "CARRY"
                                    color: "#F57F17"
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.carry : 0)
                                    color: "#E65100"
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "yards"
                                    color: "#F57F17"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // TOTAL
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 90
                            radius: 12
                            color: "#E8F5E9"
                            border.color: "#66BB6A"
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                
                                Label { 
                                    text: "TOTAL"
                                    color: "#2E7D32"
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label { 
                                    text: (win ? win.total : 0)
                                    color: "#1B5E20"
                                    font.pixelSize: 38
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Label {
                                    text: "yards"
                                    color: "#2E7D32"
                                    font.pixelSize: 11
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}