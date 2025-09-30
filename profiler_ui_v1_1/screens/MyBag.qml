import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: myBag
    width: 480
    height: 800

    Rectangle { anchors.fill: parent; color: "#0D1117" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        // --- Header ---
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
                text: "My Bag"
                color: "#F0F6FC"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: "Clubs in bag for current profile:"
            color: "#8B949E"
            font.pixelSize: 16
        }

        // --- Driver & Woods ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 6

                Label { text: "Driver & Woods"; color: "#F0F6FC"; font.pixelSize: 20; font.bold: true }

                Label { text: "Driver – 10.5°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "3 Wood – 15°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "5 Wood – 18°"; color: "#A6D189"; font.pixelSize: 16 }
            }
        }

        // --- Hybrids & Long Irons ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 6

                Label { text: "Hybrids / Long Irons"; color: "#F0F6FC"; font.pixelSize: 20; font.bold: true }

                Label { text: "3 Hybrid – 19°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "4 Iron – 21°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "5 Iron – 24°"; color: "#A6D189"; font.pixelSize: 16 }
            }
        }

        // --- Irons ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 6

                Label { text: "Irons"; color: "#F0F6FC"; font.pixelSize: 20; font.bold: true }

                Label { text: "6 Iron – 28°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "7 Iron – 34°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "8 Iron – 38°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "9 Iron – 42°"; color: "#A6D189"; font.pixelSize: 16 }
            }
        }

        // --- Wedges ---
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: "#161B22"
            border.color: "#30363D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 6

                Label { text: "Wedges"; color: "#F0F6FC"; font.pixelSize: 20; font.bold: true }

                Label { text: "Pitching Wedge – 46°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "Gap Wedge – 50°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "Sand Wedge – 56°"; color: "#A6D189"; font.pixelSize: 16 }
                Label { text: "Lob Wedge – 60°"; color: "#A6D189"; font.pixelSize: 16 }
            }
        }
    }
}
