import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: bar
    color: "#FFFFFF"; radius: 10; height: 64
    border.color: "#D0D5DD"
    border.width: 2

    signal onOpenSettings()
    signal onOpenHistory()
    signal onOpenMyBag()
    signal onOpenCalibration()

    RowLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 14
        Button {
            text: "⚙ Settings"
            background: Rectangle { color: "#3A86FF"; radius: 6 }
            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: bar.onOpenSettings()
        }
        Button {
            text: "📊 History"
            background: Rectangle { color: "#3A86FF"; radius: 6 }
            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: bar.onOpenHistory()
        }
        Button {
            text: "🛠 My Bag"
            background: Rectangle { color: "#3A86FF"; radius: 6 }
            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: bar.onOpenMyBag()
        }
        Button {
            text: "🧪 Calibration"
            background: Rectangle { color: "#3A86FF"; radius: 6 }
            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: bar.onOpenCalibration()
        }
    }
}
