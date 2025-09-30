import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    width: 480; height: 800

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Button { text: "‹ Back"; onClicked: StackView.view.pop() }
            Label { text: "History"; color: "white"; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
            Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#243241" }
        Label { text: "Shot list & stats will appear here.", color: "#9FB0C4" }
    }
}
