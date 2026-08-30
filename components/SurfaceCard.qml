import QtQuick
import qs.Commons

// SurfaceCard.qml — shared card surface with an optional left accent bar.
// Callers set `height`; children are laid out by the caller.

Rectangle {
  id: root
  property color accentBarColor: "transparent"  // non-transparent → accent bar shown

  // Passed in explicitly so the card never reaches into parent.shell.
  required property color surfaceColor
  required property color borderColor

  width: parent.width
  radius: Style.cornerRadius
  color: root.surfaceColor
  border.width: Style.space(1)
  border.color: root.borderColor

  Rectangle {
    visible: root.accentBarColor !== "transparent"
    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
    width: Style.space(3)
    color: root.accentBarColor
    radius: Style.cornerRadius
  }
}
