import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.1

Item {
    id: profileScreen
    width: 480
    height: 800

    property var win: null

    // ---------- Persistent storage ----------
    Settings {
        id: store
        category: "profiles"
        property string active: "Guest"
        property string listJson: "[]"
    }

    // Local model (synced to store)
    property var profiles: []
    property string activeProfile: "Guest"

    // ---------- lifecycle ----------
    Component.onCompleted: {
        try {
            profiles = JSON.parse(store.listJson || "[]")
        } catch(e) {
            profiles = []
        }
        activeProfile = store.active || "Guest"

        if (win) win.activeProfile = activeProfile
    }

    function persist() {
        store.listJson = JSON.stringify(profiles)
        store.active = activeProfile
        if (win) win.activeProfile = activeProfile
    }

    Rectangle { 
        anchors.fill: parent
        color: "#0D1117" 
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
                    stack.goBack()
                }
            }
            
            Label {
                text: "Profiles"
                color: "#F0F6FC"
                font.pixelSize: 24
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // --- Current User + My Bag ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Label {
                    text: "Current User:  " + activeProfile
                    color: "#A6D189"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }
                
                Button {
                    text: "My Bag"
                    implicitWidth: 100
                    implicitHeight: 44
                    background: Rectangle { color: "#1F6FEB"; radius: 6 }
                    contentItem: Text { 
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
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

        // --- Create New Profile ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 10
            color: "#161B22"
            border.color: "#30363D"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Label {
                    text: "Create New Profile"
                    color: "#F0F6FC"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    TextField {
                        id: nameInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        placeholderText: "Enter name (e.g., Riley)"
                        font.pixelSize: 16
                        color: "#F0F6FC"
                        placeholderTextColor: "#8B949E"
                        
                        background: Rectangle {
                            color: "#1C2128"
                            radius: 6
                            border.color: nameInput.activeFocus ? "#58A6FF" : "#30363D"
                            border.width: 1
                        }
                    }
                    
                    Button {
                        text: "Save"
                        implicitWidth: 90
                        implicitHeight: 50
                        
                        background: Rectangle {
                            color: parent.pressed ? "#1D6F2F" : "#238636"
                            radius: 6
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
                                profiles.push(n)
                                activeProfile = n
                                nameInput.text = ""
                                persist()
                                // Force list refresh
                                list.model = null
                                list.model = profiles
                            }
                        }
                    }
                }
            }
        }

        // --- Saved Profiles List ---
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                
                Label {
                    text: "Saved Profiles"
                    color: "#F0F6FC"
                    font.pixelSize: 18
                    font.bold: true
                }

                // Empty state
                Label {
                    visible: profiles.length === 0
                    text: "No profiles yet. Create one above."
                    color: "#8B949E"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // Profile List
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: profiles

                    delegate: Rectangle {
                        width: list.width
                        height: 70
                        color: "#1C2128"
                        radius: 6
                        border.color: "#30363D"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Label {
                                text: modelData
                                color: "#F0F6FC"
                                font.pixelSize: 17
                                font.bold: activeProfile === modelData
                                Layout.fillWidth: true
                            }
                            
                            Button {
                                text: "Set Active"
                                implicitWidth: 90
                                implicitHeight: 45
                                visible: activeProfile !== modelData
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#1D6F2F" : "#238636"
                                    radius: 6
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    activeProfile = modelData
                                    persist()
                                    // Force list refresh to update visibility
                                    list.model = null
                                    list.model = profiles
                                }
                            }
                            
                            Label {
                                text: "✓ Active"
                                color: "#A6D189"
                                font.pixelSize: 14
                                font.bold: true
                                visible: activeProfile === modelData
                                // Layout.preferredWidth: 90
                            }
                            
                            Button {
                                text: "Bag"
                                implicitWidth: 60
                                implicitHeight: 45
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#1558B8" : "#1F6FEB"
                                    radius: 6
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    // Set this profile as active first
                                    activeProfile = modelData
                                    persist()
                                    // Then open My Bag
                                    stack.push(Qt.resolvedUrl("MyBag.qml"), { win: win })
                                }
                            }
                            
                            Button {
                                text: "🗑"
                                implicitWidth: 50
                                implicitHeight: 45
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#B02A2A" : "#DA3633"
                                    radius: 6
                                }
                                
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 18
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    soundManager.playClick()
                                    deleteDialog.profileToDelete = modelData
                                    deleteDialog.profileIndex = index
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
        width: 380
        height: 220
        modal: true
        
        property string profileToDelete: ""
        property int profileIndex: -1
        
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
                text: "Delete Profile?"
                color: "#F0F6FC"
                font.pixelSize: 22
                font.bold: true
            }
            
            Label {
                text: "Are you sure you want to delete \"" + deleteDialog.profileToDelete + "\"?\n\nThis action cannot be undone."
                color: "#8B949E"
                font.pixelSize: 15
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
                    implicitHeight: 50
                    
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
                        deleteDialog.close()
                    }
                }
                
                Button {
                    text: "Delete"
                    Layout.fillWidth: true
                    implicitHeight: 50
                    
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
                        
                        var idx = deleteDialog.profileIndex
                        var nameToDelete = deleteDialog.profileToDelete
                        
                        // Remove from array
                        profiles.splice(idx, 1)
                        
                        // If we deleted the active profile, switch to first one or Guest
                        if (activeProfile === nameToDelete) {
                            activeProfile = profiles.length ? profiles[0] : "Guest"
                        }
                        
                        persist()
                        
                        // Force list refresh
                        list.model = null
                        list.model = profiles
                        
                        deleteDialog.close()
                    }
                }
            }
        }
    }
}