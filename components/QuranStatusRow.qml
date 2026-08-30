// components/QuranStatusRow.qml — shared search-status row.
//
// Status label (left) + flexible spacer + keyboard hint (right), shown below
// the search field while a query is active. Extracted from QuranTab and
// HadithTab so the two tabs share one status/hint row and can't drift apart.

import QtQuick
import qs.Commons
import "../i18n.js" as I18n

Row {
  id: root
  width: parent.width
  spacing: Style.spacing.sm

  required property string label
  required property bool showHint
  required property string language
  required property color contentForeground
  required property color mutedForeground
  required property real dimOpacity
  required property string fontFamily

  Text {
    id: statusLabel
    width: Math.min(Style.space(260), implicitWidth)
    text: root.label
    textFormat: Text.PlainText
    color: root.mutedForeground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Item {
    width: Math.max(0, parent.width - statusLabel.width - keyboardHint.implicitWidth - Style.spacing.sm * 2)
    height: Style.space(1)
  }

  Text {
    id: keyboardHint
    text: root.showHint ? I18n.get("search.hint", root.language) : ""
    textFormat: Text.PlainText
    color: root.contentForeground
    opacity: root.dimOpacity
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
