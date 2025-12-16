import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: historyScreen
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

    property var historyData: []
    property bool showExportNotification: false
    property string exportFilePath: ""

    Component.onCompleted: {
        loadHistory()
    }

    Connections {
        target: historyManager
        function onHistoryChanged() {
            loadHistory()
        }
    }

    function loadHistory() {
        var historyJson = historyManager.getAllHistory()
        historyData = JSON.parse(historyJson)
    }

    function formatTimestamp(timestamp) {
        var date = new Date(timestamp)
        return date.toLocaleDateString() + " " + date.toLocaleTimeString()
    }

    function exportData() {
        var filePath = historyManager.exportToCSV()
        if (filePath) {
            exportFilePath = filePath
            showExportNotification = true
            exportTimer.restart()
        }
    }

    Timer {
        id: exportTimer
        interval: 3000
        onTriggered: showExportNotification = false
    }

    Rectangle {
        anchors.fill: parent
        color: bg
    }

    // Export Success Notification
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        width: 500
        height: 70
        radius: 10
        color: success
        visible: showExportNotification
        z: 1000
        opacity: showExportNotification ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15

            Rectangle {
                width: 4
                height: 28
                color: "white"
                radius: 2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Export Successful!"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "Saved to: " + exportFilePath
                    color: "white"
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Back"
                implicitWidth: 100
                implicitHeight: 48
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
                    stack.goBack()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Shot History - All Profiles"
                color: text
                font.pixelSize: 24
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Export Data"
                implicitWidth: 130
                implicitHeight: 48
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
                    exportData()
                }
            }

            Button {
                text: "Clear All"
                implicitWidth: 120
                implicitHeight: 48
                scale: pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                background: Rectangle {
                    color: parent.pressed ? "#B02A27" : danger
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
                    clearConfirmDialog.open()
                }
            }
        }

        // Table Header
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: card
            border.color: edge
            border.width: 2
            radius: 8

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Label {
                    width: 120
                    text: "Date/Time"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 70
                    text: "Profile"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 70
                    text: "Club"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 65
                    text: "Ball Spd"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 65
                    text: "Club Spd"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 55
                    text: "Smash"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 55
                    text: "Launch"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 55
                    text: "Spin"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 55
                    text: "Carry"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    width: 55
                    text: "Total"
                    color: text
                    font.pixelSize: 11
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Scrollable Table Content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: card
            border.color: edge
            border.width: 2
            radius: 8

            ScrollView {
                anchors.fill: parent
                anchors.margins: 2
                clip: true

                ListView {
                    id: historyList
                    anchors.fill: parent
                    model: historyData
                    spacing: 2

                    delegate: Rectangle {
                        width: historyList.width
                        height: 45
                        color: index % 2 === 0 ? "#FFFFFF" : "#F9FAFB"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 3

                            Label {
                                width: 120
                                text: formatTimestamp(modelData.timestamp)
                                color: hint
                                font.pixelSize: 10
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            Label {
                                width: 70
                                text: modelData.profile || "Unknown"
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            Label {
                                width: 70
                                text: modelData.club || "N/A"
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            Label {
                                width: 65
                                text: modelData.ballSpeed.toFixed(1)
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                width: 65
                                text: modelData.clubSpeed.toFixed(1)
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                width: 55
                                text: modelData.smash.toFixed(2)
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                width: 55
                                text: modelData.launch.toFixed(1) + "°"
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                width: 55
                                text: modelData.spin
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                width: 55
                                text: modelData.carry
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }

                            Label {
                                width: 55
                                text: modelData.total
                                color: text
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Empty state
                    Label {
                        anchors.centerIn: parent
                        text: "No shots recorded yet.\n\nSimulate a shot to see it here!"
                        color: hint
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        visible: historyData.length === 0
                    }
                }
            }
        }

        // Info text
        Label {
            Layout.fillWidth: true
            text: historyData.length + " total shot(s) recorded across all profiles"
            color: hint
            font.pixelSize: 12
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Clear confirmation dialog
    Dialog {
        id: clearConfirmDialog
        title: "Clear All History"
        anchors.centerIn: parent
        modal: true

        contentItem: Rectangle {
            implicitWidth: 350
            implicitHeight: 150
            color: card
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Label {
                    text: "Are you sure you want to delete all shot history for ALL profiles?\n\nThis action cannot be undone!"
                    color: text
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        text: "Cancel"
                        Layout.fillWidth: true
                        implicitHeight: 40
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B8BBC1" : edge
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        contentItem: Text {
                            text: parent.text
                            color: text
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            soundManager.playClick()
                            clearConfirmDialog.close()
                        }
                    }

                    Button {
                        text: "Delete All"
                        Layout.fillWidth: true
                        implicitHeight: 40
                        scale: pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        background: Rectangle {
                            color: parent.pressed ? "#B02A27" : danger
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
                            historyManager.clearAllHistory()
                            clearConfirmDialog.close()
                        }
                    }
                }
            }
        }
    }
}
