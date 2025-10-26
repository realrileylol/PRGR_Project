import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.1

Item {
    id: myBag
    width: 480
    height: 800

    property var win

    // Local copy of club bag
    property var presets: ({})
    property string currentPreset: "Default Set"
    property var currentClubs: ({})

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
        console.log("Saved presets:", currentPreset)
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
            presets[name] = JSON.parse(JSON.stringify(currentClubs)) // Deep copy
            currentPreset = name
            currentClubs = presets[name]
            savePresets()
            
            // Update dropdown
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
        color: "#0D1117" 
    }

    // ENTIRE SCREEN IS NOW SCROLLABLE
    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 20
            
            // Add top padding
            Item { height: 24 }

            // --- Header ---
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 12
                
                Button {
                    text: "← Back"
                    implicitWidth: 100
                    implicitHeight: 48
                    background: Rectangle { color: "#238636"; radius: 6 }
                    contentItem: Text { 
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
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
                    color: "#F0F6FC"
                    font.pixelSize: 24
                    font.bold: true
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // --- Preset Selector ---
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: 70
                radius: 10
                color: "#161B22"
                border.color: "#30363D"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    
                    Label {
                        text: "Preset:"
                        color: "#F0F6FC"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    ComboBox {
                        id: presetSelector
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        
                        model: Object.keys(presets)
                        
                        onCurrentTextChanged: {
                            if (currentText && currentText !== currentPreset) {
                                switchPreset(currentText)
                            }
                        }
                        
                        background: Rectangle {
                            color: "#1C2128"
                            radius: 6
                            border.color: presetSelector.pressed ? "#58A6FF" : "#30363D"
                            border.width: 2
                        }
                        
                        contentItem: Text {
                            leftPadding: 12
                            text: presetSelector.displayText
                            font.pixelSize: 16
                            font.bold: true
                            color: "#F0F6FC"
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        delegate: ItemDelegate {
                            width: presetSelector.width
                            height: 45
                            
                            contentItem: Text {
                                text: modelData
                                color: "#F0F6FC"
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                            }
                            
                            background: Rectangle {
                                color: parent.highlighted ? "#1F6FEB" : "#1C2128"
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
                                color: "#1C2128"
                                border.color: "#30363D"
                                border.width: 2
                                radius: 6
                            }
                        }
                    }
                    
                    Button {
                        text: "+"
                        implicitWidth: 50
                        implicitHeight: 50
                        
                        background: Rectangle {
                            color: parent.pressed ? "#1558B8" : "#1F6FEB"
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 24
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
                        text: "🗑"
                        implicitWidth: 50
                        implicitHeight: 50
                        visible: currentPreset !== "Default Set"
                        
                        background: Rectangle {
                            color: parent.pressed ? "#B02A2A" : "#DA3633"
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            soundManager.playClick()
                            deletePreset(currentPreset)
                        }
                    }
                }
            }

            Label {
                text: "Tap any club to edit its loft"
                color: "#8B949E"
                font.pixelSize: 13
                Layout.leftMargin: 24
            }

            // All club categories
            ClubCategory {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                title: "Driver & Woods"
                clubNames: ["Driver", "3 Wood", "5 Wood"]
            }

            ClubCategory {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                title: "Hybrids / Long Irons"
                clubNames: ["3 Hybrid", "4 Iron", "5 Iron"]
            }

            ClubCategory {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                title: "Irons"
                clubNames: ["6 Iron", "7 Iron", "8 Iron", "9 Iron"]
            }

            ClubCategory {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                title: "Wedges"
                clubNames: ["PW", "GW", "SW", "LW"]
            }

            // --- Save Button ---
            Button {
                text: "💾 Save & Return"
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                implicitHeight: 56
                
                background: Rectangle {
                    color: parent.pressed ? "#1D6F2F" : "#238636"
                    radius: 12
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
                    savePresets()
                    stack.goBack()
                }
            }
            
            // Add bottom padding
            Item { height: 24 }
        }
    }

    // --- New Preset Dialog ---
    Dialog {
        id: newPresetDialog
        anchors.centerIn: parent
        width: 380
        height: 220
        modal: true
        title: "Create New Preset"
        
        background: Rectangle {
            color: "#161B22"
            radius: 10
            border.color: "#30363D"
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            Label {
                text: "Preset Name:"
                color: "#F0F6FC"
                font.pixelSize: 16
            }
            
            TextField {
                id: presetNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                placeholderText: "e.g., Blade Irons, Backup Set"
                font.pixelSize: 16
                color: "#F0F6FC"
                
                background: Rectangle {
                    color: "#1C2128"
                    radius: 6
                    border.color: presetNameInput.activeFocus ? "#58A6FF" : "#30363D"
                    border.width: 2
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
                        color: parent.pressed ? "#5A6168" : "#6C757D"
                        radius: 8
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
                        presetNameInput.text = ""
                        newPresetDialog.close()
                    }
                }
                
                Button {
                    text: "Create"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    
                    background: Rectangle {
                        color: parent.pressed ? "#1558B8" : "#1F6FEB"
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

    // --- Club Category Component ---
    component ClubCategory: Rectangle {
        property string title: ""
        property var clubNames: []
        
        implicitHeight: col.implicitHeight + 30
        radius: 10
        color: "#161B22"
        border.color: "#30363D"

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Label {
                text: title
                color: "#F0F6FC"
                font.pixelSize: 16
                font.bold: true
            }

            Repeater {
                model: clubNames
                
                ClubRow {
                    Layout.fillWidth: true
                    clubName: modelData
                }
            }
        }
    }

    // --- Individual Club Row Component ---
    component ClubRow: Rectangle {
        property string clubName: ""
        
        implicitHeight: 45
        radius: 6
        color: "#1C2128"
        border.color: clubMouseArea.containsMouse ? "#58A6FF" : "#30363D"
        
        MouseArea {
            id: clubMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                soundManager.playClick()
                editDialog.open()
            }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            Label {
                text: clubName
                color: "#F0F6FC"
                font.pixelSize: 15
                Layout.fillWidth: true
            }
            
            Label {
                text: (currentClubs[clubName] || 0).toFixed(1) + "°"
                color: "#A6D189"
                font.pixelSize: 15
                font.bold: true
            }
            
            Label {
                text: "✏️"
                font.pixelSize: 14
            }
        }
        
        // Edit Dialog
        Dialog {
            id: editDialog
            anchors.centerIn: Overlay.overlay
            width: 350
            height: 280
            modal: true
            
            background: Rectangle {
                color: "#161B22"
                radius: 10
                border.color: "#30363D"
                border.width: 2
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                Label {
                    text: "Edit " + clubName
                    color: "#F0F6FC"
                    font.pixelSize: 20
                    font.bold: true
                }
                
                Label {
                    text: loftSlider.value.toFixed(1) + "°"
                    color: "#A6D189"
                    font.pixelSize: 36
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Slider {
                    id: loftSlider
                    Layout.fillWidth: true
                    from: 8
                    to: 65
                    stepSize: 0.5
                    value: currentClubs[clubName] || 34.0
                    
                    background: Rectangle {
                        x: loftSlider.leftPadding
                        y: loftSlider.topPadding + loftSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: loftSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#30363D"

                        Rectangle {
                            width: loftSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#1F6FEB"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: loftSlider.leftPadding + loftSlider.visualPosition * (loftSlider.availableWidth - width)
                        y: loftSlider.topPadding + loftSlider.availableHeight / 2 - height / 2
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: loftSlider.pressed ? "#58A6FF" : "#1F6FEB"
                        border.color: "#F0F6FC"
                        border.width: 2
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
                            color: parent.pressed ? "#5A6168" : "#6C757D"
                            radius: 8
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
                            editDialog.close()
                        }
                    }
                    
                    Button {
                        text: "Save"
                        Layout.fillWidth: true
                        implicitHeight: 48
                        
                        background: Rectangle {
                            color: parent.pressed ? "#1D6F2F" : "#238636"
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
                            currentClubs[clubName] = loftSlider.value
                            currentClubs = currentClubs // Force refresh
                            editDialog.close()
                        }
                    }
                }
            }
        }
    }
}