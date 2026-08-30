import QtQuick

Item {
  id: root
  implicitHeight: quranTab.implicitHeight

  required property QtObject shell

  readonly property alias searchFocused: quranTab.searchFocused
  readonly property alias surah: quranTab.surah
  readonly property alias ayah: quranTab.ayah
  readonly property alias quranTab: quranTab

  function openSurahAyah(surahId, ayahN) { quranTab.openSurahAyah(surahId, ayahN) }

  QuranTab {
    id: quranTab
    anchors.fill: parent
    quran: root.shell.quran
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
    keyCatcher: root.shell.keyCatcher  // accessible via shell context
    dimOpacity: root.shell.dimOpacity
    language: root.shell.language
    onSurahChanged: root.shell.onReaderPositionChanged()
    onAyahChanged: root.shell.onReaderPositionChanged()
  }
}
