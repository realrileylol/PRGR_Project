import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: profileScreen
    width: 800
    height: 480

    property var win: null

    // Theme colors matching main GUI
    readonly property color bg: "#F5F7FA"
    readonly property color card: "#FFFFFF"
    readonly property color edge: "#D0D5DD"
    readonly property color text: "#1A1D23"
    readonly property color hint: "#5F6B7A"
    readonly property color accent: "#3A86FF"
    readonly property color success: "#34C759"
    readonly property color danger: "#DA3633"

    // Local model
    property var profiles: []
    property string activeProfile: "Guest"
    property int refreshCounter: 0  // Used to force refresh

    // ---------- lifecycle ----------
    Component.onCompleted: {
        loadProfiles()
    }

    function loadProfiles() {
        var profilesJson = profileManager.getProfilesJson("profiles")
        profiles = JSON.parse(profilesJson)
        activeProfile = profileManager.getActiveProfile()
        
        if (win) win.activeProfile = activeProfile
        
        refreshCounter++  // Trigger refresh
    }

    function saveActiveProfile() {
        profileManager.setActiveProfile(activeProfile)
        if (win) win.activeProfile = activeProfile
        refreshCounter++  // Trigger refresh
    }

    Rectangle { 
        anchors.fill: parent
        color: bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Button {
                text: "← Back"
                implicitWidth: 100
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
                    stack.goBack()
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Label {
                text: "Profiles"
                color: text
                font.pixelSize: 24
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
        }

        // --- Create New Profile ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: 10
            color: card
            border.color: edge
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Label {
                    text: "Create New Profile:"
                    color: text
                    font.pixelSize: 16
                    font.bold: true
                }
                
                TextField {
                    id: nameInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    placeholderText: "Enter name (e.g., Riley)"
                    font.pixelSize: 16
                    color: text
                    
                    background: Rectangle {
                        color: "#F5F7FA"
                        radius: 8
                        border.color: nameInput.activeFocus ? accent : edge
                        border.width: 2
                    }
                    
                    onAccepted: {
                        if (text.trim().length > 0) {
                            createButton.clicked()
                        }
                    }
                }
                
                Button {
                    id: createButton
                    text: "Save"
                    implicitWidth: 100
                    implicitHeight: 50
                    
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
                        var n = (nameInput.text || "").trim()
                        if (!n.length) return
                        
                        // Check for duplicates (case-insensitive)
                        var exists = false
                        for (var i = 0; i < profiles.length; i++) {
                            if (profiles[i].toLowerCase() === n.toLowerCase()) {
                                exists = true
                                break
                            }
                        }
                        
                        if (!exists) {
                            // Create the profile
                            profileManager.createProfile(n)
                            
                            // Set as active
                            activeProfile = n
                            saveActiveProfile()
                            
                            // Clear input
                            nameInput.text = ""
                            
                            // Reload profiles
                            loadProfiles()
                        } else {
                            console.log("Profile already exists:", n)
                        }
                    }
                }
            }
        }

        // --- Saved Profiles List (FILLS REMAINING SPACE) ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: card
            border.color: edge
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Label {
                    text: "Saved Profiles"
                    color: text
                    font.pixelSize: 18
                    font.bold: true
                }

                // Empty state
                Label {
                    visible: profiles.length === 0
                    text: "No profiles yet. Create one above."
                    color: hint
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // Profile List
                ListView {
                    id: profilesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    visible: profiles.length > 0
                    model: profiles

                    delegate: Rectangle {
                        width: profilesList.width
                        height: 75
                        color: "#F5F7FA"
                        radius: 8
                        border.color: edge
                        border.width: 1
                        
                        // Force delegate to update when refreshCounter changes
                        property int refresh: profileScreen.refreshCounter
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            
                            Label {
                                text: modelData
                                color: profileScreen.text
                                font.pixelSize: 18
                                font.bold: profileScreen.activeProfile === modelData
                                Layout.fillWidth: true
                            }
                            
                            Button {
                                text: "Set Active"
                                implicitWidth: 100
                                implicitHeight: 50
                                visible: profileScreen.activeProfile !== modelData
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#2D9A4F" : profileScreen.success
                                    radius: 8
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
                                    profileScreen.activeProfile = modelData
                                    profileScreen.saveActiveProfile()
                                }
                            }
                            
                            Rectangle {
                                implicitWidth: 100
                                implicitHeight: 50
                                color: "transparent"
                                visible: profileScreen.activeProfile === modelData
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓ Active"
                                    color: profileScreen.success
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }
                            
                            Button {
                                text: "My Bag"
                                implicitWidth: 100
                                implicitHeight: 50
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#2563EB" : profileScreen.accent
                                    radius: 8
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
                                    // Set this profile as active first
                                    profileScreen.activeProfile = modelData
                                    profileScreen.saveActiveProfile()
                                    // Then open My Bag
                                    stack.push(Qt.resolvedUrl("MyBag.qml"), { win: win })
                                }
                            }
                            
                            Button {
                                text: "Delete"
                                implicitWidth: 90
                                implicitHeight: 50
                                visible: modelData !== "Guest"  // Can't delete Guest
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#B02A2A" : profileScreen.danger
                                    radius: 8
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
                                    deleteDialog.profileToDelete = modelData
                                    deleteDialog.open()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Delete Confirmation Dialog ---
    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: 400
        height: 240
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string profileToDelete: ""
        
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
                text: "Delete Profile?"
                color: text
                font.pixelSize: 24
                font.bold: true
            }
            
            Label {
                text: "Are you sure you want to delete \"" + deleteDialog.profileToDelete + "\"?\n\nThis action cannot be undone."
                color: hint
                font.pixelSize: 15
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Button {
                    text: "No, Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 55
                    
                    background: Rectangle {
                        color: parent.pressed ? "#B8BBC1" : "#C8CCD4"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: text
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        deleteDialog.close()
                    }
                }
                
                Button {
                    text: "Yes, Delete"
                    Layout.fillWidth: true
                    implicitHeight: 55
                    
                    background: Rectangle {
                        color: parent.pressed ? "#B02A2A" : danger
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
                        
                        // Delete the profile
                        profileManager.deleteProfile(deleteDialog.profileToDelete)
                        
                        // Reload profiles (this also updates activeProfile if needed)
                        loadProfiles()
                        
                        deleteDialog.close()
                    }
                }
            }
        }
    }
}