import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: bar
    color: "#171A1F"; radius: 10; height: 64
    signal onOpenSettings()
    signal onOpenHistory()
    signal onOpenMyBag()
    signal onOpenCalibration()

    RowLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 14
        Button { text: "⚙ Settings"; onClicked: bar.onOpenSettings() }
        Button { text: "📊 History"; onClicked: bar.onOpenHistory() }
        Button { text: "🛠 My Bag"; onClicked: bar.onOpenMyBag() }
        Button { text: "🧪 Calibration"; onClicked: bar.onOpenCalibration() }
    }
}
