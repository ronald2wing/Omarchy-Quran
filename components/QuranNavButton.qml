// components/QuranNavButton.qml — gold icon button for reader navigation.
//
// Gold glyph on a transparent surface; the surface gains a faint gold tint on
// hover (or a slightly stronger one when `active`), and the glyph stays gold so
// it reads against both the tint and the dark green background. A `large`
// variant widens the hit target for the primary surah/hadith paging buttons.
import QtQuick
import qs.Commons

Rectangle {
  id: btn

  required property color accentColor
  required property color hoverTint
  required property color selectionTint
  required property string fontFamily

  property string glyph: ""
  property string iconSource: ""
  property bool active: false
  // Large variant for primary reader navigation: bigger hit target and
  // glyph so surah/hadith paging is easy to hit.
  property bool large: false
  signal clicked()

  width: btn.large ? Style.space(40) : Style.spacing.controlHeight
  height: btn.large ? Style.space(40) : Style.spacing.controlHeight
  radius: Style.cornerRadius
  color: btn.active
    ? btn.selectionTint
    : (btnMouse.containsMouse ? btn.hoverTint : "transparent")

  Image {
    anchors.centerIn: parent
    visible: btn.iconSource !== ""
    source: btn.iconSource
    width: Style.font.iconLarge
    height: Style.font.iconLarge
    fillMode: Image.PreserveAspectFit
  }

  Text {
    anchors.centerIn: parent
    visible: btn.iconSource === ""
    text: btn.glyph
    textFormat: Text.PlainText
    color: btn.accentColor
    font.family: btn.fontFamily
    font.pixelSize: btn.large ? Style.font.iconLarge : Style.font.body
  }

  MouseArea {
    id: btnMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}