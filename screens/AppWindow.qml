import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 800
    height: 480

    property var win

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

    // ORDERED metrics - always displayed in this order
    property var orderedMetrics: [
        { id: "clubSpeed", label: "CLUB SPEED", unit: "mph", getValue: function() { return win ? win.clubSpeed.toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "ballSpeed", label: "BALL SPEED", unit: "mph", getValue: function() { return win ? win.ballSpeed.toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "smash", label: "SMASH", unit: "factor", getValue: function() { return win ? win.smash.toFixed(2) : "0.00" }, color: "#F5F7FA", borderColor: edge },
        { id: "launch", label: "LAUNCH", unit: "degrees", getValue: function() { return win ? win.launchDeg.toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "spin", label: "SPIN", unit: "rpm", getValue: function() { return win ? win.spinEst : 0 }, color: "#F5F7FA", borderColor: edge },
        { id: "carry", label: "CARRY", unit: "yards", getValue: function() { return win ? win.carry : 0 }, color: "#FFF8E1", borderColor: "#FFD54F", textColor: "#F57F17", valueColor: "#E65100" },
        { id: "total", label: "TOTAL", unit: "yards", getValue: function() { return win ? win.total : 0 }, color: "#E8F5E9", borderColor: "#66BB6A", textColor: "#2E7D32", valueColor: "#1B5E20" },
        { id: "apex", label: "APEX", unit: "yards", getValue: function() { return win ? (win.carry * 0.7).toFixed(0) : "0" }, color: "#F5F7FA", borderColor: edge },
        { id: "descent", label: "DESCENT", unit: "degrees", getValue: function() { return win ? (win.launchDeg * 1.3).toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "hangTime", label: "HANG TIME", unit: "sec", getValue: function() { return win ? ((win.carry / 180) * 5.2).toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge },
        { id: "efficiency", label: "EFFICIENCY", unit: "%", getValue: function() { return win ? ((win.smash / 1.50) * 100).toFixed(0) : "0" }, color: "#F5F7FA", borderColor: edge },
        { id: "spinLoft", label: "SPIN LOFT", unit: "degrees", getValue: function() { return win ? (win.launchDeg + 3).toFixed(1) : "0.0" }, color: "#F5F7FA", borderColor: edge }
    ]

    // Track which metrics are active (initially all main ones)
    property var activeMetricIds: ["clubSpeed", "ballSpeed", "smash", "launch", "spin", "carry", "total"]

    // Calculate dynamic sizing based on number of active metrics and available space
    function getMetricSize(availableWidth, availableHeight) {
        var count = activeMetricIds.length
        if (count === 0) return { width: 200, height: 200, fontSize: 48, labelSize: 14, unitSize: 12 }
        
        var spacing = 10
        var maxWidth = availableWidth - 28 // Account for margins
        
        // Try different column configurations to find the best fit
        var bestSize = 0
        var bestCols = 1
        
        for (var cols = 1; cols <= count; cols++) {
            var rows = Math.ceil(count / cols)
            var itemWidth = (maxWidth - (cols - 1) * spacing) / cols
            var itemHeight = (availableHeight - (rows - 1) * spacing) / rows
            
            // Use the smaller dimension to keep squares
            var size = Math.min(itemWidth, itemHeight)
            
            if (size > bestSize) {
                bestSize = size
                bestCols = cols
            }
        }
        
        // Clamp size to reasonable bounds
        bestSize = Math.max(bestSize, 80)
        bestSize = Math.min(bestSize, 400)
        
        var fontSize = Math.max(24, Math.min(64, bestSize * 0.28))
        var labelSize = Math.max(9, Math.min(16, bestSize * 0.08))
        var unitSize = Math.max(8, Math.min(14, bestSize * 0.07))
        
        return { width: bestSize, height: bestSize, fontSize: fontSize, labelSize: labelSize, unitSize: unitSize }
    }

    // Get active metrics in order
    function getActiveMetrics() {
        var active = []
        for (var i = 0; i < orderedMetrics.length; i++) {
            if (activeMetricIds.indexOf(orderedMetrics[i].id) !== -1) {
                active.push(orderedMetrics[i])
            }
        }
        return active
    }

    // Get available metrics (not active) in order
    function getAvailableMetrics() {
        var available = []
        for (var i = 0; i < orderedMetrics.length; i++) {
            if (activeMetricIds.indexOf(orderedMetrics[i].id) === -1) {
                available.push(orderedMetrics[i])
            }
        }
        return available
    }

    function removeMetric(metricId) {
        var newMetrics = []
        for (var i = 0; i < activeMetricIds.length; i++) {
            if (activeMetricIds[i] !== metricId) {
                newMetrics.push(activeMetricIds[i])
            }
        }
        activeMetricIds = newMetrics
    }

    function addMetrics(metricIds) {
        var newMetrics = activeMetricIds.slice()
        for (var i = 0; i < metricIds.length; i++) {
            if (newMetrics.indexOf(metricIds[i]) === -1) {
                newMetrics.push(metricIds[i])
            }
        }
        activeMetricIds = newMetrics
    }

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
                
                // Profile/Settings/Camera buttons (Profile contains My Bag)
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

                    Button {
                        text: "Camera"
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
                            // Camera functionality to be implemented
                            console.log("Camera button clicked")
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
                        
                        Item { Layout.fillHeight: true }
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
                            color: success
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

        // ========== PAGE 2: METRICS ==========
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
                            
                            Button {
                                text: "+"
                                implicitWidth: 36
                                implicitHeight: 36
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : "white"
                                    radius: 8
                                    opacity: 0.9
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.pressed ? "white" : accent
                                    font.pixelSize: 24
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    addMetricDialog.selectedMetrics = []
                                    addMetricDialog.open()
                                }
                            }
                        }
                    }

                    // Metrics Grid - FILLS SPACE BETWEEN HEADER AND BUTTON
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        Flow {
                            id: metricsFlow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            
                            property var sizing: getMetricSize(width, height)
                            
                            Repeater {
                                model: getActiveMetrics()
                                
                                Rectangle {
                                    property var metric: modelData
                                    
                                    width: metricsFlow.sizing.width
                                    height: metricsFlow.sizing.height
                                    radius: 12
                                    
                                    color: metric.color || "#F5F7FA"
                                    border.color: metric.borderColor || edge
                                    border.width: 2
                                    
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressAndHold: {
                                            soundManager.playClick()
                                            deleteDialog.metricToDelete = metric.id
                                            deleteDialog.metricLabel = metric.label
                                            deleteDialog.open()
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        
                                        Label { 
                                            text: metric.label
                                            color: metric.textColor || hint
                                            font.pixelSize: metricsFlow.sizing.labelSize
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Label { 
                                            text: metric.getValue()
                                            color: metric.valueColor || text
                                            font.pixelSize: metricsFlow.sizing.fontSize
                                            font.bold: true
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Label {
                                            text: metric.unit
                                            color: metric.textColor || hint
                                            font.pixelSize: metricsFlow.sizing.unitSize
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // SIMULATE SHOT BUTTON
                    Button {
                        visible: win ? win.useSimulateButton : false
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 14
                        Layout.preferredHeight: visible ? 70 : 0
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
                }
            }
        }
    }

    // Delete Metric Dialog
    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: 350
        height: 200
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string metricToDelete: ""
        property string metricLabel: ""
        
        background: Rectangle {
            color: card
            radius: 12
            border.color: edge
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            Label {
                text: "Remove Metric?"
                color: text
                font.pixelSize: 20
                font.bold: true
            }
            
            Label {
                text: "Remove \"" + deleteDialog.metricLabel + "\" from your metrics view?"
                color: hint
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: text
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        deleteDialog.close()
                    }
                }
                
                Button {
                    text: "Remove"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#B02A2A" : "#DA3633"
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
                        removeMetric(deleteDialog.metricToDelete)
                        deleteDialog.close()
                    }
                }
            }
        }
    }

    // Add Metric Dialog with Multi-Select
    Dialog {
        id: addMetricDialog
        anchors.centerIn: parent
        width: 450
        height: 450
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property var selectedMetrics: []
        
        background: Rectangle {
            color: card
            radius: 12
            border.color: edge
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Label {
                text: "Add Metrics"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            Label {
                text: "Select metrics to add (will be added in order):"
                color: hint
                font.pixelSize: 14
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    
                    Repeater {
                        model: getAvailableMetrics()
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: 55
                            radius: 8
                            color: checkBox.checked ? "#E8F0FE" : "#F5F7FA"
                            border.color: edge
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                CheckBox {
                                    id: checkBox
                                    checked: addMetricDialog.selectedMetrics.indexOf(modelData.id) !== -1
                                    
                                    onCheckedChanged: {
                                        var selected = addMetricDialog.selectedMetrics.slice()
                                        var idx = selected.indexOf(modelData.id)
                                        
                                        if (checked && idx === -1) {
                                            selected.push(modelData.id)
                                        } else if (!checked && idx !== -1) {
                                            selected.splice(idx, 1)
                                        }
                                        
                                        addMetricDialog.selectedMetrics = selected
                                    }
                                }
                                
                                Label {
                                    text: modelData.label
                                    color: text
                                    font.pixelSize: 16
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                
                                Label {
                                    text: modelData.unit
                                    color: hint
                                    font.pixelSize: 13
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    soundManager.playClick()
                                    checkBox.checked = !checkBox.checked
                                }
                            }
                        }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E5E7EB" : "#F5F7FA"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: text
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        addMetricDialog.close()
                    }
                }
                
                Button {
                    text: "Add Selected (" + addMetricDialog.selectedMetrics.length + ")"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    enabled: addMetricDialog.selectedMetrics.length > 0
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#2563EB" : accent) : "#C8CCD4"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "white" : "#5F6B7A"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        addMetrics(addMetricDialog.selectedMetrics)
                        addMetricDialog.close()
                    }
                }
            }
        }
    }
}