// components/HadithPage.qml — Lazy-loaded wrapper around the Hadith tab reader.
//
// HadithTab is the mature hadith browser; this page exists only to forward
// Shell palette and state into HadithTab. It delegates every palette/language/data
// property from root.shell into the tab and re-exposes the two properties
// Shell's close()/focus logic needs (searchFocused, saveState). No browser
// logic lives here.

import QtQuick

Item {
  id: root
  implicitHeight: hadithTab.implicitHeight
  required property QtObject shell
  readonly property alias searchFocused: hadithTab.searchFocused
  readonly property alias hadithTab: hadithTab
  function saveState() { hadithTab.saveState() }

  HadithTab {
    id: hadithTab
    anchors.fill: parent
    accentColor: root.shell.accentColor
    hoverTint: root.shell.hoverTint
    selectionTint: root.shell.selectionTint
    contentForeground: root.shell.contentForeground
    mutedForeground: root.shell.mutedForeground
    surfaceColor: root.shell.surfaceColor
    borderColor: root.shell.borderColor
    fontFamily: root.shell.fontFamily
    readerFontFamily: root.shell.readerFontFamily
    arabicFontFamily: root.shell.arabicFontFamily
    keyCatcher: root.shell.keyCatcher
    dimOpacity: root.shell.dimOpacity
    language: root.shell.language
  }
}
