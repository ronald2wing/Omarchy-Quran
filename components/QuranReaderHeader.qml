// components/QuranReaderHeader.qml — shared reader header for the Quran and Hadith readers.
//
// Prev/next gold buttons flank a centered column of title, subtitle, and an
// ayah PositionBar. The trailing menu button toggles the surahs browser
// (showExtraButton); the center column width shrinks by that button's width
// plus one extra spacing only when it is present.
import QtQuick
import qs.Commons

Row {
  id: readerHeader
  width: parent.width
  spacing: Style.spacing.sm

  required property color accentColor
  required property color hoverTint
  required property color selectionTint
  required property color contentForeground
  required property color surfaceColor
  required property string fontFamily
  required property Item keyCatcher
  required property real dimOpacity

  property string title
  property string subtitle
  property int positionValue
  property int positionMax
  property string positionLabelPrefix
  property int positionOffset
  property int positionTotalMax
  property string positionChapterLabel
  property string positionTotalLabel
  property bool showExtraButton
  property bool extraButtonActive

  signal jump(int target)
  signal prev()
  signal next()
  signal extraClicked()

  QuranNavButton {
    id: prevButton
    accentColor: readerHeader.accentColor
    hoverTint: readerHeader.hoverTint
    selectionTint: readerHeader.selectionTint
    fontFamily: readerHeader.fontFamily
    glyph: "\u25C0"
    large: true
    onClicked: readerHeader.prev()
  }

  Column {
    width: readerHeader.width - prevButton.width - nextButton.width
      - (readerHeader.showExtraButton ? extraButton.width + readerHeader.spacing : 0)
      - readerHeader.spacing * 2
    spacing: Style.spacing.sm

    Text {
      width: parent.width
      text: readerHeader.title
      textFormat: Text.PlainText
      color: readerHeader.contentForeground
      font.family: readerHeader.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight

      // Plain Text is mouse-transparent, so a click here falls through to
      // bodyScroll, which grabs it for drag detection and leaves the search
      // field focused. TapHandler is passive, so it clears focus without
      // stealing the Flickable's drag gesture.
      TapHandler {
        onTapped: readerHeader.keyCatcher.forceActiveFocus()
      }
    }

    Text {
      width: parent.width
      text: readerHeader.subtitle
      textFormat: Text.PlainText
      color: readerHeader.contentForeground
      opacity: readerHeader.dimOpacity
      font.family: readerHeader.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }

    QuranPositionBar {
      value: readerHeader.positionValue
      max: readerHeader.positionMax
      labelPrefix: readerHeader.positionLabelPrefix
      offset: readerHeader.positionOffset
      totalMax: readerHeader.positionTotalMax
      chapterLabel: readerHeader.positionChapterLabel
      totalLabel: readerHeader.positionTotalLabel
      accentColor: readerHeader.accentColor
      contentForeground: readerHeader.contentForeground
      surfaceColor: readerHeader.surfaceColor
      fontFamily: readerHeader.fontFamily
      onJump: function(target) { readerHeader.jump(target) }
    }
  }

  QuranNavButton {
    id: nextButton
    accentColor: readerHeader.accentColor
    hoverTint: readerHeader.hoverTint
    selectionTint: readerHeader.selectionTint
    fontFamily: readerHeader.fontFamily
    glyph: "\u25B6"
    large: true
    onClicked: readerHeader.next()
  }

  QuranNavButton {
    id: extraButton
    accentColor: readerHeader.accentColor
    hoverTint: readerHeader.hoverTint
    selectionTint: readerHeader.selectionTint
    fontFamily: readerHeader.fontFamily
    visible: readerHeader.showExtraButton
    iconSource: Qt.resolvedUrl("../assets/icons/menu-cream.svg")
    glyph: ""
    large: true
    active: readerHeader.extraButtonActive
    onClicked: readerHeader.extraClicked()
  }
}