import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.1

Item {
    id: myBag
    anchors.fill: parent

    property var win

    // Local copy of club bag
    property var presets: ({})
    property string currentPreset: "Default Set"
    property var currentClubs: ({})

    // Theme colors matching main GUI
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color cardHover: "#F9FAFB"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color success: "#34C759"
    readonly property color danger: "#DA3633"

    Settings {
        id: clubStorage
        category: "clubs"
        property string presetsJson: ""
        property string activePreset: "Default Set"
    }

    Component.onCompleted: {
        loadPresets()
    }

    function loadPresets() {
        if (clubStorage.presetsJson) {
            try {
                presets = JSON.parse(clubStorage.presetsJson)
            } catch(e) {
                presets = win ? win.clubPresets : { "Default Set": getDefaultClubs() }
            }
        } else {
            presets = win ? win.clubPresets : { "Default Set": getDefaultClubs() }
        }
        
        currentPreset = clubStorage.activePreset || "Default Set"
        if (!presets[currentPreset]) {
            currentPreset = Object.keys(presets)[0] || "Default Set"
        }
        currentClubs = presets[currentPreset] || {}
        
        // Update dropdown
        presetSelector.currentIndex = Object.keys(presets).indexOf(currentPreset)
    }

    function getDefaultClubs() {
        return {
            "Driver": 10.5,
            "3 Wood": 15.0,
            "5 Wood": 18.0,
            "3 Hybrid": 19.0,
            "4 Iron": 21.0,
            "5 Iron": 24.0,
            "6 Iron": 28.0,
            "7 Iron": 34.0,
            "8 Iron": 38.0,
            "9 Iron": 42.0,
            "PW": 46.0,
            "GW": 50.0,
            "SW": 56.0,
            "LW": 60.0
        }
    }

    function savePresets() {
        presets[currentPreset] = currentClubs
        clubStorage.presetsJson = JSON.stringify(presets)
        clubStorage.activePreset = currentPreset
        
        if (win) {
            win.clubPresets = presets
            win.activePreset = currentPreset
            win.activeClubBag = currentClubs
        }
    }

    function switchPreset(presetName) {
        if (presets[presetName]) {
            currentPreset = presetName
            currentClubs = presets[presetName]
            savePresets()
        }
    }

    function createNewPreset(name) {
        if (name && !presets[name]) {
            presets[name] = JSON.parse(JSON.stringify(currentClubs))
            currentPreset = name
            currentClubs = presets[name]
            savePresets()
            
            presetSelector.model = Object.keys(presets)
            presetSelector.currentIndex = Object.keys(presets).indexOf(name)
        }
    }

    function deletePreset(name) {
        if (Object.keys(presets).length > 1 && name !== "Default Set") {
            delete presets[name]
            if (currentPreset === name) {
                currentPreset = Object.keys(presets)[0]
                currentClubs = presets[currentPreset]
            }
            savePresets()
            presetSelector.model = Object.keys(presets)
        }
    }

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
                    anchors.margins: 20
                    spacing: 15
                    
                    Button {
                        text: "← Back"
                        implicitHeight: 45
                        implicitWidth: 100
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#2D9A4F" : success
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
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
                            savePresets()
                            stack.goBack()
                        }
                    }
                    
                    Label {
                        text: "My Bag"
                        color: text
                        font.pixelSize: 26
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    
                    Button {
                        text: "Reset"
                        implicitHeight: 45
                        implicitWidth: 90
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B02A2A" : danger
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            soundManager.playClick()
                            resetDialog.open()
                        }
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
                    
                    // Preset Selector
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        height: 60
                        radius: 10
                        color: card
                        border.color: edge
                        border.width: 2
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            
                            Label {
                                text: "Preset:"
                                color: text
                                font.pixelSize: 16
                                font.bold: true
                            }
                            
                            ComboBox {
                                id: presetSelector
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                
                                model: Object.keys(presets)
                                
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== currentPreset) {
                                        switchPreset(currentText)
                                    }
                                }
                                
                                background: Rectangle {
                                    color: "#F5F7FA"
                                    radius: 6
                                    border.color: presetSelector.pressed ? accent : edge
                                    border.width: 2
                                }
                                
                                contentItem: Text {
                                    leftPadding: 12
                                    text: presetSelector.displayText
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: text
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                delegate: ItemDelegate {
                                    width: presetSelector.width
                                    height: 40
                                    
                                    contentItem: Text {
                                        text: modelData
                                        color: text
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 12
                                    }
                                    
                                    background: Rectangle {
                                        color: parent.highlighted ? "#E8F0FE" : "white"
                                    }
                                }
                                
                                popup: Popup {
                                    y: presetSelector.height + 2
                                    width: presetSelector.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: presetSelector.popup.visible ? presetSelector.delegateModel : null
                                        currentIndex: presetSelector.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                    
                                    background: Rectangle {
                                        color: card
                                        border.color: edge
                                        border.width: 2
                                        radius: 6
                                    }
                                }
                            }
                            
                            Button {
                                text: "+"
                                implicitWidth: 40
                                implicitHeight: 40
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : accent
                                    radius: 6
                                    Behavior on color { ColorAnimation { duration: 200 } }
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
                                    soundManager.playClick()
                                    newPresetDialog.open()
                                }
                            }
                            
                            Button {
                                text: "Delete"
                                implicitWidth: 70
                                implicitHeight: 40
                                visible: currentPreset !== "Default Set" && Object.keys(presets).length > 1
                                scale: pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                background: Rectangle {
                                    color: parent.pressed ? "#B02A2A" : danger
                                    radius: 6
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    deletePresetDialog.open()
                                }
                            }
                        }
                    }
                    
                    // Info hint
                    Label {
                        text: "Click any club to edit its loft angle"
                        color: hint
                        font.pixelSize: 13
                        Layout.leftMargin: 20
                    }
                    
                    // Clubs Grid
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 12
                        
                        Repeater {
                            model: Object.keys(currentClubs)
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 70
                                radius: 10
                                color: clubMouseArea.containsMouse ? cardHover : card
                                border.color: clubMouseArea.containsMouse ? accent : edge
                                border.width: 2
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                
                                MouseArea {
                                    id: clubMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        soundManager.playClick()
                                        editDialog.clubName = modelData
                                        editDialog.currentLoft = currentClubs[modelData] || 34.0
                                        editDialog.open()
                                    }
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 12
                                    
                                    // Club info
                                    ColumnLayout {
                                        spacing: 4
                                        Layout.fillWidth: true
                                        
                                        Label {
                                            text: modelData
                                            color: text
                                            font.pixelSize: 17
                                            font.bold: true
                                        }
                                        
                                        Label {
                                            text: (currentClubs[modelData] || 0).toFixed(1) + "° loft"
                                            color: hint
                                            font.pixelSize: 14
                                        }
                                    }
                                    
                                    // Edit indicator
                                    Label {
                                        text: "Edit"
                                        color: clubMouseArea.containsMouse ? accent : hint
                                        font.pixelSize: 13
                                        font.bold: clubMouseArea.containsMouse
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { height: 20 }
                }
            }
        }
    }

    // Edit Club Dialog
    Dialog {
        id: editDialog
        anchors.centerIn: parent
        width: 400
        height: 300
        modal: true
        
        property string clubName: ""
        property real currentLoft: 0
        
        background: Rectangle {
            color: card
            radius: 12
            border.color: edge
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 20
            
            Label {
                text: "Edit " + editDialog.clubName
                color: text
                font.pixelSize: 24
                font.bold: true
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 100
                radius: 10
                color: "#F5F7FA"
                border.color: accent
                border.width: 2
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 20
                    
                    Button {
                        text: "−"
                        implicitWidth: 50
                        implicitHeight: 50
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B02A2A" : danger
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 28
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            soundManager.playClick()
                            editDialog.currentLoft = Math.max(5, editDialog.currentLoft - 0.5)
                        }
                    }
                    
                    Label {
                        text: editDialog.currentLoft.toFixed(1) + "°"
                        color: text
                        font.pixelSize: 40
                        font.bold: true
                        Layout.preferredWidth: 120
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Button {
                        text: "+"
                        implicitWidth: 50
                        implicitHeight: 50
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#2D9A4F" : success
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 28
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            soundManager.playClick()
                            editDialog.currentLoft = Math.min(70, editDialog.currentLoft + 0.5)
                        }
                    }
                }
            }
            
            Label {
                text: "Range: 5° - 70°"
                color: hint
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        editDialog.close()
                    }
                }

                Button {
                    text: "Save"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#2D9A4F" : success
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        currentClubs[editDialog.clubName] = editDialog.currentLoft
                        currentClubs = currentClubs // Force refresh
                        savePresets()
                        editDialog.close()
                    }
                }
            }
        }
    }

    // New Preset Dialog
    Dialog {
        id: newPresetDialog
        anchors.centerIn: parent
        width: 380
        height: 220
        modal: true
        
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
                text: "Create New Preset"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            TextField {
                id: presetNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                placeholderText: "Enter preset name..."
                font.pixelSize: 15
                color: text
                
                background: Rectangle {
                    color: "#F5F7FA"
                    radius: 8
                    border.color: presetNameInput.activeFocus ? accent : edge
                    border.width: 2
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        presetNameInput.text = ""
                        newPresetDialog.close()
                    }
                }

                Button {
                    text: "Create"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#2563EB" : accent
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        var name = presetNameInput.text.trim()
                        if (name) {
                            createNewPreset(name)
                            presetNameInput.text = ""
                            newPresetDialog.close()
                        }
                    }
                }
            }
        }
    }

    // Delete Preset Dialog
    Dialog {
        id: deletePresetDialog
        anchors.centerIn: parent
        width: 380
        height: 200
        modal: true
        
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
                text: "Delete Preset?"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            Label {
                text: "Delete \"" + currentPreset + "\"? This cannot be undone."
                color: hint
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        deletePresetDialog.close()
                    }
                }

                Button {
                    text: "Delete"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B02A2A" : danger
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        deletePreset(currentPreset)
                        deletePresetDialog.close()
                    }
                }
            }
        }
    }

    // Reset Dialog
    Dialog {
        id: resetDialog
        anchors.centerIn: parent
        width: 380
        height: 220
        modal: true
        
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
                text: "Reset to Defaults?"
                color: text
                font.pixelSize: 22
                font.bold: true
            }
            
            Label {
                text: "Reset all clubs in \"" + currentPreset + "\" to default loft values?"
                color: hint
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        resetDialog.close()
                    }
                }

                Button {
                    text: "Reset"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    scale: pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    background: Rectangle {
                        color: parent.pressed ? "#B02A2A" : danger
                        radius: 8
                        Behavior on color { ColorAnimation { duration: 200 } }
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
                        currentClubs = getDefaultClubs()
                        savePresets()
                        resetDialog.close()
                    }
                }
            }
        }
    }
}