// components/QuranResultCard.qml — one search-result row shared by HadithTab
// and QuranTab. Transparent until selected/hovered, 1px gold border when
// selected, bold title, optional grade badge / go-hint, optional Arabic line
// + English line.
import QtQuick
import qs.Commons
import "../i18n.js" as I18n

Rectangle {
  id: card

  required property bool selected
  required property color accentColor
  required property color contentForeground
  required property color mutedForeground
  required property color surfaceColor
  required property color borderColor
  required property color hoverTint
  required property color selectionTint
  required property string fontFamily
  required property string arabicFontFamily
  required property string language

  // Bold title with an optional trailing grade badge (Hadith) or go-hint (Quran).
  property string title: ""
  property string grade: ""            // non-empty → "[grade]" badge
  property string goHint: ""           // non-empty → "Go to verse" hint
  property bool goHintAccent: false      // gold-tint goHint when this result's ayah is the open one

  // Body: an optional Arabic line (Quran) and an English line. `englishRich`
  // switches the English line between Text.RichText (Quran highlight markup)
  // and plain text (Hadith, already truncated by the tab).
  property string arabic: ""           // empty → hidden
  property string english: ""
  property bool englishRich: false

  signal entered(int rowIndex)
  signal clicked()

  // Row index and total count, both passed in by the tab: this card sits inside
  // a wrapper Item (not the delegate root), so ListView context injection and
  // the ListView.view attached property are not available here.
  required property int rowIndex
  property int itemCount: 0

  // width is set by the caller.
  height: cardColumn.implicitHeight + Style.spacing.md * 2
  radius: Style.cornerRadius
  color: card.selected ? card.selectionTint
    : (cardMouse.containsMouse ? card.hoverTint : card.surfaceColor)
  border.width: Style.space(1)
  border.color: card.selected ? card.accentColor : card.borderColor

  Column {
    id: cardColumn
    anchors.fill: parent
    anchors.margins: Style.spacing.md
    spacing: Style.spacing.xs

    Row {
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        id: titleText
        text: card.title
        textFormat: Text.PlainText
        color: card.selected ? card.accentColor : card.contentForeground
        font.family: card.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        elide: Text.ElideRight
        // Shrink to leave room for the trailing badge/hint so a long title
        // truncates instead of pushing them out of the card.
        width: Math.max(0, parent.width
          - (card.grade !== "" ? gradeBadge.implicitWidth + parent.spacing : 0)
          - (card.goHint !== "" ? goHintText.implicitWidth + parent.spacing : 0))
      }

      Text {
        id: gradeBadge
        visible: card.grade !== ""
        text: card.grade !== "" ? I18n.template("grade.bracket", card.language, {grade: card.grade}) : ""
        textFormat: Text.PlainText
        color: card.contentForeground
        opacity: 0.65
        font.family: card.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        id: goHintText
        visible: card.goHint !== ""
        text: card.goHint
        textFormat: Text.PlainText
        color: card.goHintAccent ? card.accentColor : card.contentForeground
        font.family: card.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.8
      }

    }

    Text {
      id: arabicText
      width: parent.width
      visible: card.arabic !== ""
      text: card.arabic
      textFormat: Text.PlainText
      color: card.contentForeground
      font.family: card.arabicFontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignRight
      wrapMode: Text.WordWrap
      maximumLineCount: 2
    }

    Text {
      width: parent.width
      visible: card.english !== ""
      text: card.english
      textFormat: card.englishRich ? Text.RichText : Text.PlainText
      color: card.mutedForeground
      font.family: card.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      maximumLineCount: 3
    }
  }

  Rectangle {
    visible: card.rowIndex < card.itemCount - 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: card.borderColor
  }

  MouseArea {
    id: cardMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: card.entered(card.rowIndex)
    onClicked: card.clicked()
  }
}
