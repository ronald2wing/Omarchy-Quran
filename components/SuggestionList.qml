// components/SuggestionList.qml — autocomplete dropdown for the Quran and
// Hadith search fields. Renders one row per suggestion; clicking emits
// applySuggestion. Shared because QuranTab and HadithTab render identical
// dropdowns.
import QtQuick
import qs.Commons

Column {
  id: root
  required property var suggestions
  required property color surfaceColor
  required property color hoverTint
  required property color borderColor
  required property color contentForeground
  required property string fontFamily
  signal applySuggestion(string text)
  width: parent.width
  spacing: Style.spacing.xxs
  Repeater {
    model: root.suggestions
    delegate: Rectangle {
      width: root.width
      height: Style.space(32)
      radius: Style.cornerRadius
      color: sugMouse.containsMouse ? root.hoverTint : root.surfaceColor
      border.width: Style.space(1)
      border.color: root.borderColor
      Text {
        anchors.left: parent.left; anchors.leftMargin: Style.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
        text: modelData; textFormat: Text.PlainText
        color: root.contentForeground
        font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
      }
      MouseArea {
        id: sugMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.applySuggestion(modelData)
      }
    }
  }
}
