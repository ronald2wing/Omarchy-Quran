// components/QuranSearchField.qml — search input for the Quran and Hadith tabs.
//
// A TextField restyled to the Quran palette: cream text on the surface green,
// with a gold border once focused. An inline clear button (visible once text
// is entered) sits inside the field; arrow-key navigation is
// gated by `hasResults`; Up/Down arrows emit navigate(int delta).
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

TextField {
  id: field

  // Bound so a huge pasted query can't fan out into unbounded search work.
  maximumLength: 500

  required property string closeGlyph
  required property color accentColor
  required property color contentForeground
  required property color mutedForeground
  required property real dimOpacity
  required property color surfaceColor
  required property color borderColor
  required property string fontFamily
  required property Item keyCatcher

  property bool hasResults: false
  signal navigate(int delta)

  foreground: contentForeground
  accent: accentColor
  color: contentForeground
  // Cream at dimOpacity — brighter than mutedForeground so the
  // placeholder stays legible on the dark green surface.
  placeholderTextColor: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, dimOpacity)
  selectionColor: accentColor
  selectedTextColor: surfaceColor
  font.family: fontFamily
  rightPadding: Style.space(24)

  background: Rectangle {
    radius: Style.cornerRadius
    color: field.surfaceColor
    border.width: Style.space(1)
    border.color: field.activeFocus ? field.accentColor : field.borderColor
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (!field.hasResults) return
    if (event.key === Qt.Key_Down) {
      field.navigate(1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      field.navigate(-1)
      event.accepted = true
    }
  }

  // Dismiss the search: drop focus and return it to the panel key catcher.
  function dismissSearch() {
    field.focus = false
    keyCatcher.forceActiveFocus()
  }

  Keys.onEscapePressed: field.dismissSearch()

  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.spacing.controlHeight
    height: Style.spacing.controlHeight
    radius: Style.cornerRadius
    visible: field.text !== ""
    color: clearMouse.containsMouse ? field.surfaceColor : "transparent"

    Text {
      anchors.centerIn: parent
      text: field.closeGlyph
      textFormat: Text.PlainText
      color: clearMouse.containsMouse ? field.accentColor : field.mutedForeground
      font.family: field.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: clearMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        field.clear()
        field.forceActiveFocus()
      }
    }
  }
}
