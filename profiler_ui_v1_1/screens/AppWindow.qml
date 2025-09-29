import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 480
    height: 800

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

    // ---------- Carry & Total Calculation ----------
    function estimateCarry7i(clubSpeed, spinRpm) {
        const baseCS = 92.0;
        const baseCarry = 182.0;
        const speedExp = 1.045;
        var carry = baseCarry * Math.pow(clubSpeed / baseCS, speedExp);
        carry += (6500 - spinRpm) * 0.006;
        return Math.round(carry);
    }

    function estimateTotal(carryYd, turf) {
        var roll = (turf === "firm") ? 14 : (turf === "soft") ? 7 : 10;
        return carryYd + roll;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ---------- Top Bar ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
                text: "👤 " + (win ? win.activeProfile : "Guest")
                color: text; font.pixelSize: 20; font.bold: true
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Profile"
                onClicked: { stack.push(Qt.resolvedUrl("screens/ProfileScreen.qml")) }
            }
            Button {
                text: "Settings"
                onClicked: {
                    stack.openSettings()
                }

            }

        }
        // ---------- Context Strip ----------
        Rectangle {
            Layout.fillWidth: true
            radius: 10
            color: card
            border.color: edge
            height: 70
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 20
                Label {
                    text: "Club: " + (win ? win.currentClub : "--")
                    color: text; font.pixelSize: 16
                }
                Label {
                    text: "Loft: " + (win ? win.currentLoft.toFixed(1) : "--") + "°"
                    color: text; font.pixelSize: 16
                }
                Label {
                    text: "Ball: " + (win ? (win.currentBallPreset || "Generic") : "Generic")
                    color: text; font.pixelSize: 16
                }
            }
        }

        // ---------- Metrics ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 420
            radius: 14
            color: card
            border.color: edge

            GridLayout {
                anchors.fill: parent
                anchors.margins: 20
                columns: 2
                columnSpacing: 30
                rowSpacing: 20

                // BALL SPEED
                ColumnLayout {
                    spacing: 4
                    Label { text: "BALL SPEED"; color: hint; font.pixelSize: 14 }
                    Label { text: (win ? win.ballSpeed.toFixed(1) : "--") + " mph"; color: text; font.pixelSize: 36; font.bold: true }
                }

                // CLUB SPEED
                ColumnLayout {
                    spacing: 4
                    Label { text: "CLUB SPEED"; color: hint; font.pixelSize: 14 }
                    Label { text: (win ? win.clubSpeed.toFixed(1) : "--") + " mph"; color: text; font.pixelSize: 32; font.bold: true }
                }

                // SMASH
                ColumnLayout {
                    spacing: 4
                    Label { text: "SMASH FACTOR"; color: hint; font.pixelSize: 14 }
                    Label { text: (win ? win.smash.toFixed(2) : "--"); color: text; font.pixelSize: 32; font.bold: true }
                }

                // SPIN
                ColumnLayout {
                    spacing: 4
                    Label { text: "SPIN RATE"; color: hint; font.pixelSize: 14 }
                    Label { text: (win ? win.spinEst : 0) + " rpm"; color: text; font.pixelSize: 32; font.bold: true }
                }

                // CARRY
                ColumnLayout {
                    spacing: 4
                    Label { text: "CARRY"; color: hint; font.pixelSize: 14 }
                    Label { text: (win ? win.carry : 0) + " yd"; color: text; font.pixelSize: 32; font.bold: true }
                }

                // TOTAL
                ColumnLayout {
                    spacing: 4
                    Label { text: "TOTAL"; color: hint; font.pixelSize: 14 }
                    Label { text: (win ? win.total : 0) + " yd"; color: text; font.pixelSize: 32; font.bold: true }
                }
            }
        }

        // ---------- Simulate Shot ----------
        Button {
            Layout.alignment: Qt.AlignHCenter
            width: 280
            height: 48
            text: "Simulate Shot"
            background: Rectangle { color: accent; radius: 12 }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                if (!win) return;

                function rand(min, max) { return min + Math.random() * (max - min) }

                win.clubSpeed = rand(90, 96)
                win.smash = rand(1.37, 1.41)
                win.ballSpeed = win.clubSpeed * win.smash
                win.spinEst = Math.round(rand(5800, 6700))

                var carryCalc = estimateCarry7i(win.clubSpeed, win.spinEst)
                win.carry = Math.max(0, carryCalc)
                win.total = estimateTotal(win.carry, "normal")
            }
        }

        // ---------- Status Line ----------
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: 8
            color: "#E9EEF5"
            border.color: edge
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: ok; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Ready to capture next shot…"; color: text; font.pixelSize: 14 }
            }
        }
    }
}
