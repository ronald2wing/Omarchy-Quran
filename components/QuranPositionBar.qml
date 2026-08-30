// components/QuranPositionBar.qml — shared position indicator for the Quran
// and Hadith readers.
//
// A track showing where the current ayah (or hadith) sits within its surah (or
// chapter). The track is a faint gold tint and the progress fill is Islamic
// gold; clicking or dragging jumps to the item at that x and hovering shows the
// target position in a gold-bordered tooltip. In the Hadith reader the optional
// offset/totalMax/chapterLabel/totalLabel properties extend the tooltip with
// the position within the whole collection.
import QtQuick
import qs.Commons

Rectangle {
  id: positionBar

  required property color accentColor
  required property color contentForeground
  required property color surfaceColor
  required property string fontFamily

  property int value: 0
  property int max: 0
  property string labelPrefix: ""
  property int offset: 0       // added to hoverValue for the global hadith number
  property int totalMax: 0     // total hadiths in the collection (0 = disabled)
  property string chapterLabel: ""  // e.g. "This chapter"
  property string totalLabel: ""    // e.g. "All of Bukhari"
  signal jump(int target)

  // "Label N/M" lines for the tooltip. The two lines may have slightly
  // different widths (proportional font), but the centered tooltip handles that.
  function hoverLabelText() {
    var local = barMouse.hoverValue + "/" + positionBar.max
    var glob = (barMouse.hoverValue + positionBar.offset) + "/" + positionBar.totalMax
    if (positionBar.totalMax > 0 && positionBar.max > 0) {
      return positionBar.chapterLabel + " " + local + "\n"
        + positionBar.totalLabel + " " + glob
    }
    if (positionBar.totalMax > 0)
      return positionBar.totalLabel + " " + glob
    if (positionBar.max > 0)
      return positionBar.labelPrefix + " " + local
    return positionBar.labelPrefix + barMouse.hoverValue
  }

  // Ayah number at the given x position, clamped to [1, max].
  function valueAt(mx) {
    return Math.max(1, Math.min(positionBar.max, Math.round(mx / width * positionBar.max)))
  }

  width: parent.width
  height: Style.space(8)
  radius: height / 2
  // Accent color at 15% alpha — a visible track that contrasts with both the
  // dark surface and the solid-gold fill, rather than blending into the card.
  color: Qt.rgba(positionBar.accentColor.r, positionBar.accentColor.g, positionBar.accentColor.b, 0.15)

  Rectangle {
    width: positionBar.max > 0 ? parent.width * (positionBar.value / positionBar.max) : 0
    height: parent.height
    radius: height / 2
    color: positionBar.accentColor
  }

  MouseArea {
    id: barMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    property int hoverValue: positionBar.max > 0 ? positionBar.valueAt(mouseX) : 0
    function jumpTo(mx) {
      if (positionBar.max <= 0) return
      positionBar.jump(positionBar.valueAt(mx))
    }
    onClicked: function(mouse) { jumpTo(mouse.x) }
    onPositionChanged: function(mouse) {
      if (pressed) jumpTo(mouse.x)
    }
  }

  QuranTooltip {
    id: posTooltip
    visible: barMouse.containsMouse && barMouse.hoverValue > 0
    text: positionBar.hoverLabelText()
    accentColor: positionBar.accentColor
    surfaceColor: positionBar.surfaceColor
    contentForeground: positionBar.contentForeground
    fontFamily: positionBar.fontFamily
  }
}
