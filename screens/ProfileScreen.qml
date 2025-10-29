import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: profileScreen
    width: 800
    height: 480

    property var win: null

    // DARK THEME COLORS
    readonly property color bg: "#0D1117"
    readonly property color card: "#161B22"
    readonly property color edge: "#30363D"
    readonly property color text: "#F0F6FC"
    readonly property color hint: "#8B949E"
    readonly property color accent: "#1F6FEB"
    readonly property color success: "#238636"
    readonly property color danger: "#DA3633"

    // Local model
    property var profiles: []
    property string activeProfile: "Guest"
    property int refreshCounter: 0
    
    // Success notification
    property bool showSuccessNotification: false
    property string successMessage: ""

    Component.onCompleted: {
        loadProfiles()
    }

    function loadProfiles() {
        var profilesJson = profileManager.getProfilesJson("profiles")
        profiles = JSON.parse(profilesJson)
        activeProfile = profileManager.getActiveProfile()
        
        if (win) win.activeProfile = activeProfile
        
        refreshCounter++
    }

    function saveActiveProfile() {
        profileManager.setActiveProfile(activeProfile)
        if (win) win.activeProfile = activeProfile
        refreshCounter++
    }
    
    function showSuccess(message) {
        successMessage = message
        showSuccessNotification = true
        successTimer.restart()
    }
    
    Timer {
        id: successTimer
        interval: 2500
        onTriggered: showSuccessNotification = false
    }
    
    function getInitials(name) {
        if (!name) return "?"
        var parts = name.trim().split(/\s+/)
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
    }
    
    function getProfileColor(name) {
        var colors = ["#1F6FEB", "#FF006E", "#8338EC", "#FB5607", "#FFBE0B", "#06D6A0"]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        return colors[Math.abs(hash) % colors.length]
    }

    Rectangle { 
        anchors.fill: parent
        color: bg
    }

    // Success Toast
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        width: 350
        height: 60
        radius: 10
        color: success
        visible: showSuccessNotification
        z: 1000
        opacity: showSuccessNotification ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 12
            
            Label {
                text: "✓"
                color: "white"
                font.pixelSize: 24
                font.bold: true
            }
            
            Label {
                text: successMessage
                color: "white"
                font.pixelSize: 15
                font.bold: true
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Button {
                text: "← Back"
                implicitWidth: 100
                implicitHeight: 48
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
                    stack.goBack()
                }
            }
            
            Item { Layout.fillWidth: true }
            
            ColumnLayout {
                spacing: 2
                
                Label {
                    text: "Profiles"
                    color: text
                    font.pixelSize: 24
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Label {
                    text: profiles.length + " profile" + (profiles.length === 1 ? "" : "s")
                    color: hint
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "+ New"
                implicitWidth: 100
                implicitHeight: 48
                
                background: Rectangle {
                    color: parent.pressed ? "#1558B8" : accent
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
                    createProfileDialog.open()
                }
            }
        }

        // Profiles List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: card
            border.color: edge
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Label {
                    text: "Your Profiles"
                    color: text
                    font.pixelSize: 18
                    font.bold: true
                }

                // Empty state
                Item {
                    visible: profiles.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 15
                        
                        Label {
                            text: "👤"
                            font.pixelSize: 64
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "No profiles yet"
                            color: text
                            font.pixelSize: 20
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "Click '+ New' to create your first profile"
                            color: hint
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Profile List
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: profiles.length > 0
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    
                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 10
                        
                        Repeater {
                            model: profiles

                            Rectangle {
                                Layout.fillWidth: true
                                height: 90
                                color: card
                                radius: 10
                                border.color: profileScreen.activeProfile === modelData ? accent : edge
                                border.width: profileScreen.activeProfile === modelData ? 3 : 1
                                
                                property int refresh: profileScreen.refreshCounter
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15
                                    
                                    // Avatar
                                    Rectangle {
                                        width: 60
                                        height: 60
                                        radius: 30
                                        color: getProfileColor(modelData)
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: getInitials(modelData)
                                            color: "white"
                                            font.pixelSize: 22
                                            font.bold: true
                                        }
                                    }
                                    
                                    // Profile Info
                                    ColumnLayout {
                                        spacing: 4
                                        Layout.fillWidth: true
                                        
                                        Label {
                                            text: modelData
                                            color: profileScreen.text
                                            font.pixelSize: 18
                                            font.bold: true
                                        }
                                        
                                        Label {
                                            text: profileScreen.activeProfile === modelData ? "● Active Profile" : "Click 'Set Active' to use"
                                            color: profileScreen.activeProfile === modelData ? "#A6D189" : hint
                                            font.pixelSize: 13
                                        }
                                    }
                                    
                                    // Actions
                                    RowLayout {
                                        spacing: 8
                                        
                                        Button {
                                            text: "Set Active"
                                            implicitWidth: 90
                                            implicitHeight: 40
                                            visible: profileScreen.activeProfile !== modelData
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#1D6F2F" : profileScreen.success
                                                radius: 6
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
                                                profileScreen.activeProfile = modelData
                                                profileScreen.saveActiveProfile()
                                                profileScreen.showSuccess("Switched to " + modelData)
                                            }
                                        }
                                        
                                        Button {
                                            text: "My Bag"
                                            implicitWidth: 80
                                            implicitHeight: 40
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#1558B8" : profileScreen.accent
                                                radius: 6
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
                                                profileScreen.activeProfile = modelData
                                                profileScreen.saveActiveProfile()
                                                stack.push(Qt.resolvedUrl("MyBag.qml"), { win: win })
                                            }
                                        }
                                        
                                        Button {
                                            text: "✕"
                                            implicitWidth: 40
                                            implicitHeight: 40
                                            visible: modelData !== "Guest"
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#B02A2A" : "transparent"
                                                radius: 6
                                                border.color: profileScreen.danger
                                                border.width: 2
                                            }
                                            
                                            contentItem: Text {
                                                text: parent.text
                                                color: profileScreen.danger
                                                font.pixelSize: 18
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
            }
        }
    }

    // Create Profile Dialog
    Dialog {
        id: createProfileDialog
        anchors.centerIn: parent
        width: 450
        height: 280
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        Overlay.modal: Rectangle {
            color: "#000000CC"
        }
        
        background: Rectangle {
            color: card
            radius: 12
            border.color: edge
            border.width: 2
        }
        
        onOpened: {
            nameInput.text = ""
            nameInput.forceActiveFocus()
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 20
            
            Label {
                text: "Create New Profile"
                color: text
                font.pixelSize: 24
                font.bold: true
            }
            
            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true
                
                Label {
                    text: "Profile Name:"
                    color: text
                    font.pixelSize: 15
                    font.bold: true
                }
                
                TextField {
                    id: nameInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 55
                    placeholderText: "e.g., Riley, John, Sarah..."
                    font.pixelSize: 16
                    color: text
                    maximumLength: 20
                    
                    background: Rectangle {
                        color: "#0D1117"
                        radius: 8
                        border.color: nameInput.activeFocus ? accent : edge
                        border.width: 2
                    }
                    
                    onAccepted: {
                        if (text.trim().length > 0 && isValid) {
                            createButton.clicked()
                        }
                    }
                    
                    property bool isValid: {
                        var n = text.trim()
                        if (n.length < 2) return false
                        
                        for (var i = 0; i < profiles.length; i++) {
                            if (profiles[i].toLowerCase() === n.toLowerCase()) {
                                return false
                            }
                        }
                        return true
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Label {
                        text: nameInput.text.length + " / 20"
                        color: hint
                        font.pixelSize: 12
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Label {
                        text: {
                            var n = nameInput.text.trim()
                            if (n.length === 0) return ""
                            if (n.length < 2) return "⚠ Too short (min 2 characters)"
                            
                            for (var i = 0; i < profiles.length; i++) {
                                if (profiles[i].toLowerCase() === n.toLowerCase()) {
                                    return "⚠ Profile already exists"
                                }
                            }
                            return "✓ Valid name"
                        }
                        color: nameInput.isValid ? "#A6D189" : danger
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 55
                    
                    background: Rectangle {
                        color: parent.pressed ? "#21262D" : "#30363D"
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
                        createProfileDialog.close()
                    }
                }
                
                Button {
                    id: createButton
                    text: "Create Profile"
                    Layout.fillWidth: true
                    implicitHeight: 55
                    enabled: nameInput.isValid
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#1D6F2F" : success) : "#30363D"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "white" : hint
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        soundManager.playClick()
                        var n = nameInput.text.trim()
                        
                        if (nameInput.isValid) {
                            profileManager.createProfile(n)
                            activeProfile = n
                            saveActiveProfile()
                            showSuccess("Profile '" + n + "' created!")
                            loadProfiles()
                            createProfileDialog.close()
                        }
                    }
                }
            }
        }
    }

    // Delete Dialog
    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: 420
        height: 260
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property string profileToDelete: ""
        
        Overlay.modal: Rectangle {
            color: "#000000CC"
        }
        
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
                text: "⚠️"
                font.pixelSize: 48
                Layout.alignment: Qt.AlignHCenter
            }
            
            Label {
                text: "Delete Profile?"
                color: text
                font.pixelSize: 24
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            
            Label {
                text: "Are you sure you want to delete \"" + deleteDialog.profileToDelete + "\"?\n\nThis will permanently remove:\n• All club presets\n• All saved settings\n• This action cannot be undone"
                color: hint
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    implicitHeight: 55
                    
                    background: Rectangle {
                        color: parent.pressed ? "#21262D" : "#30363D"
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
                    text: "Delete"
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
                        profileManager.deleteProfile(deleteDialog.profileToDelete)
                        showSuccess("Profile deleted")
                        loadProfiles()
                        deleteDialog.close()
                    }
                }
            }
        }
    }
}