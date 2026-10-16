// components/QuranSearchField.qml — search input for the Quran and Hadith tabs.
//
// A plain-text TextArea restyled to the Quran palette: cream text on the
// surface green, with a gold border once focused.  An inline clear button
// (visible once text is entered) sits inside the field; arrow-key navigation
// is gated by `hasResults`; Up/Down arrows emit navigate(int delta).
//
// All paste paths (Ctrl+V, middle-click primary selection) are routed through
// a bounded out-of-process clipboard reader
// (QuranClipboardReader.qml) instead of Qt's native clipboard-change read
// path.  The default context menu (and its eager mimeData()->text() read) is
// removed via ContextMenu.menu: null.  Each transfer is capped at 4 KiB with
// a one-second deadline; oversized, failed, or invalid UTF-8 transfers leave
// the field unchanged.
//
// Qt 6 (the runtime target) notes:
//   - ContextMenu.menu: null removes the default context menu and its eager
//     mimeData()->text() clipboard read (GaugeDB #11099).
//   - Keys.BeforeItem intercepts paste keybindings before TextArea's internal
//     handler sees them.
//   - A MouseArea overlay catches middle-click (primary-selection paste)
//     routed through the bounded reader.
import QtQuick
import QtQuick.Controls
import qs.Commons

TextArea {
  id: field

  // Public API — must match the original TextField interface so QuranTab,
  // HadithTab, and HomePage need no changes.
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
  signal accepted()

  // --- style ----------------------------------------------------------------
  textFormat: TextEdit.PlainText
  wrapMode: TextEdit.NoWrap
  selectByMouse: true

  // Remove the default context menu (and its eager clipboard read) — the
  // approved Qt 6.9+ mechanism (GaugeDB #11099).  Paste is handled by our
  // bounded out-of-process reader (QuranClipboardReader), not by Qt's native
  // mimeData()->text() path.
  ContextMenu.menu: null

  // Match the original TextField's single-line appearance.
  // TextArea defaults to a tall multi-line box; NoWrap makes contentHeight
  // follow a single line, and vertical centering aligns it with the clear button.
  verticalAlignment: TextEdit.AlignVCenter

  color: contentForeground
  selectionColor: accentColor
  selectedTextColor: surfaceColor
  font.family: fontFamily

  // Padding: rightPadding leaves room for the inline clear button so the text
  // does not overlap it; leftPadding matches the original TextField's implicit
  // left inset.
  leftPadding: Style.space(8)
  rightPadding: Style.space(24)
  topPadding: Style.space(4)
  bottomPadding: Style.space(4)

  // Cream at dimOpacity — brighter than mutedForeground so the placeholder
  // stays legible on the dark green surface.
  placeholderTextColor: Qt.rgba(contentForeground.r, contentForeground.g,
                                contentForeground.b, dimOpacity)

  background: Rectangle {
    radius: Style.cornerRadius
    color: field.surfaceColor
    border.width: Style.space(1)
    border.color: field.activeFocus ? field.accentColor : field.borderColor
  }

  // --- bounded paste helper --------------------------------------------------

  QuranClipboardReader { id: pasteHelper }

  // Start a bounded async paste read for primary (middle-click) or clipboard
  // (Ctrl+V).
  function startPaste(usePrimary) {
    pasteHelper.request(field, usePrimary)
  }

  // Called back by QuranClipboardReader when the bounded pipeline exits.
  // Rejects: exit failure (non-zero code or abnormal exit status), empty
  // output, embedded NUL.  The reader has already enforced the 4096-byte cap.
  function finishPaste(output, exitCode, exitStatus) {
    if (exitCode !== 0 || exitStatus !== 0) return
    if (output.length === 0) return
    if (output.indexOf("\u0000") >= 0) return

    // Convert tabs and line breaks to spaces so paste is a single logical edit.
    output = output.replace(/\t/g, " ").replace(/[\r\n]+/g, " ")

    // If the field already has text at capacity and the paste target would
    // exceed 500, truncate the paste portion.
    var selStart = field.selectionStart
    var selEnd = field.selectionEnd
    var before = field.text.substring(0, selStart)
    var after = field.text.substring(selEnd)
    var capacity = 500 - before.length - after.length
    if (capacity <= 0) return
    if (output.length > capacity) {
      output = output.substring(0, capacity)
    }

    // Replace selected text with the pasted content.
    field.text = before + output + after
    field.cursorPosition = before.length + output.length
  }

  // Cancel any in-flight paste read (called before we modify the field via
  // other means — typing, clearing, selection changes).
  function cancelPaste() {
    pasteHelper.cancel()
  }

  // --- key handling (BeforeItem priority — fires before TextArea's native handler) ---

  Keys.priority: Keys.BeforeItem

  Keys.onPressed: function(event) {
    // Intercept paste before TextArea reads the clipboard.  Only Ctrl+V is a
    // native paste binding (QKeySequence::Paste); Shift+Insert is not.
    if (event.matches(StandardKey.Paste)) {
      field.cancelPaste()
      field.startPaste(false)
      event.accepted = true
      return
    }

    // Enter / Return — emit accepted, never insert a newline.
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      event.accepted = true
      field.accepted()
      return
    }

    // Up/Down arrow navigation.
    if (!field.hasResults) return
    if (event.key === Qt.Key_Down) {
      field.navigate(1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      field.navigate(-1)
      event.accepted = true
    }
  }

  // --- edit guards -----------------------------------------------------------

  // Enforce the 500-character maximum on any text change (covers IME input,
  // which bypasses Keys.onPressed, and paste that goes through startPaste).
  onTextChanged: {
    if (field.length > 500) {
      field.text = field.text.substring(0, 500)
    }
  }

  // Kill the in-flight paste reader when the field loses focus (the async
  // result must not clobber a different field) or when the user starts typing
  // (textEdited fires for user-initiated edits but not for programmatic
  // text = assignment, so finishPaste's set gets a clean run).
  onActiveFocusChanged: { if (!activeFocus) field.cancelPaste() }
  onTextEdited: field.cancelPaste()

  // Dismiss the search: drop focus and return it to the panel key catcher.
  function dismissSearch() {
    field.focus = false
    keyCatcher.forceActiveFocus()
  }

  Keys.onEscapePressed: field.dismissSearch()

  // TextArea.clear() exists in Qt 6 (inherited from QQuickTextEdit), but we
  // override with a thin wrapper so cancelPaste() fires before the clear.
  function clear() {
    field.cancelPaste()
    field.text = ""
  }

  // --- clear button ----------------------------------------------------------
  // Inline clear button (visible once text is entered).  The clear button sits
  // inside the field, over the right padding area.

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

  // --- middle-click paste ----------------------------------------------------
  // Middle-click → primary selection paste routed through bounded reader.
  // Left-click events pass through to TextArea for cursor placement and
  // text selection (acceptedButtons excludes Qt.LeftButton).
  // Right-click is no longer intercepted — ContextMenu.menu: null removes
  // the default context menu entirely.

  MouseArea {
    id: mouseCatcher
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onClicked: {
      field.cancelPaste()
      field.startPaste(true)
    }
  }
}