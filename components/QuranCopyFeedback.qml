// components/QuranCopyFeedback.qml — transient "Copied — ..." feedback.
//
// Shows the owning tab's copyFeedback string when non-empty and auto-clears
// via that tab's timer. Gold so the confirmation reads as an action result.
import QtQuick
import qs.Commons

Text {
  required property string copyFeedback
  required property string fontFamily
  required property color accentColor

  width: parent.width
  visible: copyFeedback !== ""
  text: copyFeedback
  textFormat: Text.PlainText
  color: accentColor
  font.family: fontFamily
  font.pixelSize: Style.font.bodySmall
  wrapMode: Text.WordWrap
  horizontalAlignment: Text.AlignHCenter
  elide: Text.ElideRight
}
