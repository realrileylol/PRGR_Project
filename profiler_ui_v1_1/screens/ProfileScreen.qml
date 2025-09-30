import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.1

Item {
    id: profileScreen
    width: 480
    height: 800

    // If AppWindow pushes this with { win: win }, we'll keep global state in sync.
    property var win: null

    // ---------- Persistent storage ----------
    Settings {
        id: store
        category: "profiles"     // creates/profiles.ini (or platform equiv.)
        property string active: "Guest"
        property string listJson: "[]"   // store array of names as JSON string
    }

    // Local model (synced to store)
    property var profiles: []
    property string activeProfile: "Guest"

    // ---------- lifecycle ----------
    Component.onCompleted: {
        // load profiles
        try {
            profiles = JSON.parse(store.listJson || "[]")
        } catch(e) {
            profiles = []
        }
        activeProfile = store.active || "Guest"

        // if win provided, keep global label in sync
        if (win) win.activeProfile = activeProfile
    }

    function persist() {
        store.listJson = JSON.stringify(profiles)
        store.active   = activeProfile
        if (win) win.activeProfile = activeProfile
    }

    Rectangle { anchors.fill: parent; color: "#0D1117" }

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
                background: Rectangle { color: "#238636"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16 }
                onClicked: stack.goBack()
            }
            Label {
                text: "Profiles"
                color: "#F0F6FC"; font.pixelSize: 26; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Current user + My Bag
        Rectangle {
            Layout.fillWidth: true
            radius: 10; color: "#161B22"; border.color: "#30363D"
            RowLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 8
                Label {
                    text: "Current User:  " + activeProfile
                    color: "#A6D189"; font.pixelSize: 18; font.bold: true
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "My Bag"
                    background: Rectangle { color: "#1F6FEB"; radius: 6 }
                    contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16 }
                    onClicked: stack.push(Qt.resolvedUrl("screens/MyBag.qml"))
                }
            }
        }

        // Create new profile (inline)
        Rectangle {
            Layout.fillWidth: true
            radius: 10; color: "#161B22"; border.color: "#30363D"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 10
                Label { text: "Create New Profile"; color: "#F0F6FC"; font.pixelSize: 20; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    TextField {
                        id: nameInput
                        Layout.fillWidth: true
                        placeholderText: "Enter name (e.g., Riley)"
                        color: "white"; placeholderTextColor: "#8B949E"
                        background: Rectangle { color: "#1C2128"; radius: 6 }
                    }
                    Button {
                        text: "Save"
                        background: Rectangle { color: "#238636"; radius: 6 }
                        contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true }
                        onClicked: {
                            var n = (nameInput.text || "").trim()
                            if (!n.length) return
                            // de-dupe (case-insensitive)
                            var exists = false
                            for (var i=0;i<profiles.length;i++) {
                                if (profiles[i].toLowerCase() === n.toLowerCase()) { exists = true; break }
                            }
                            if (!exists) profiles.push(n)
                            activeProfile = n
                            nameInput.text = ""
                            persist()
                        }
                    }
                }
            }
        }

        // Saved profiles list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10; color: "#161B22"; border.color: "#30363D"

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 10
                Label { text: "Saved Profiles"; color: "#F0F6FC"; font.pixelSize: 20; font.bold: true }

                // Empty state
                Item {
                    Layout.fillWidth: true
                    visible: profiles.length === 0
                    implicitHeight: 40
                    Label {
                        anchors.centerIn: parent
                        text: "No profiles yet. Create one above."
                        color: "#8B949E"; font.pixelSize: 14
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: profiles

                    delegate: Rectangle {
                        width: list.width
                        height: 54
                        color: "#1C2128"
                        radius: 6
                        border.color: "#30363D"
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 10
                            Label { text: modelData; color: "#F0F6FC"; font.pixelSize: 18 }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Set Active"
                                background: Rectangle { color: "#238636"; radius: 6 }
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14 }
                                onClicked: {
                                    activeProfile = modelData
                                    persist()
                                }
                            }
                            Button {
                                text: "Delete"
                                background: Rectangle { color: "#DA3633"; radius: 6 }
                                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 14 }
                                onClicked: {
                                    // remove item
                                    var idx = index
                                    profiles.splice(idx, 1)
                                    // if we deleted the active one, fall back
                                    if (activeProfile === modelData) {
                                        activeProfile = profiles.length ? profiles[0] : "Guest"
                                    }
                                    persist()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
