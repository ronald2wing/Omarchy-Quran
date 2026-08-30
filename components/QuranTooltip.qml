import QtQuick
import QtQuick.Controls as QQC
import qs.Commons

// Hover tooltip for the reader position bar (QuranPositionBar). The trigger
// item owns `visible` and the label text; this file only carries the shared
// look (background, border, font, positioning). Colors are passed in because
// the Quran palette is hardcoded and never follows the shell theme.
QQC.ToolTip {
  id: tooltip

  required property color accentColor
  required property color surfaceColor
  required property color contentForeground
  required property string fontFamily

  delay: 400
  padding: 2
  leftPadding: 6
  rightPadding: 6
  x: (parent.width - tooltip.width) / 2
  y: parent.height + 2

  background: Rectangle {
    color: tooltip.surfaceColor
    border.width: 1
    border.color: tooltip.accentColor
    radius: Style.cornerRadius
  }
  contentItem: Text {
    text: tooltip.text
    color: tooltip.contentForeground
    font.family: tooltip.fontFamily
    font.pixelSize: Style.font.bodySmall
    horizontalAlignment: Text.AlignHCenter
  }
}
