import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "components"
import "Quran.js" as Quran
import "Model.js" as Model

Panel {
  id: root
  moduleName: "quran"
  manageIpc: false

  // Injected by BarWidget.qml after load. bar comes from Panel base type.
  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  onServiceChanged: root.ensureVerseOfDay()

  property var dailyAyat: ({ date: "", reference: null, arabic: "", english: "", referenceLabel: "" })

  // --- core state ---
  property var quran: null
  property int surah: Quran.DEFAULT_SURAH
  property int ayah: Quran.DEFAULT_AYAH
  property string currentPage: "home"  // "home" | "quran" | "hadith"
  property string pendingSearch  // query carried from HomePage quick search
  property string language: "both"
  property bool stateReady
  property bool tabStateLoaded

  // --- Islamic palette ---
  readonly property color panelBackground: "#0D4028"
  readonly property color surfaceColor: "#124A30"
  readonly property color contentForeground: "#F5E6C8"
  readonly property color mutedForeground: "#8A7530"
  readonly property color accentColor: "#D4AF37"
  readonly property color islamicGreen: "#1B6B4A"
  readonly property color borderColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)
  readonly property color selectionTint: Qt.rgba(islamicGreen.r, islamicGreen.g, islamicGreen.b, 0.14)
  readonly property color hoverTint: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.10)
  readonly property real dimOpacity: 0.55

  // Exposed so pages can reach the shared key catcher.
  property alias keyCatcher: keyCatcher

  property HomePage homePage: homePageInst
  property QuranPage quranPage: quranPageInst
  property HadithPage hadithPage: hadithPageLoader.item

  // Pre-seed Hadith data (~13MB JSON parse) in background when the panel first opens.
  property bool hadithPageLoaded

  readonly property var panelOwner: hostWidget || root
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  FontLoader {
    id: amiriQuran
    source: Qt.resolvedUrl("assets/fonts/AmiriQuran.ttf")
  }
  readonly property string arabicFontFamily: amiriQuran.status === FontLoader.Ready
    ? amiriQuran.name : root.fontFamily

  // Reading font for English body text. Noto Sans is a proportional humanist
  // sans-serif; Qt's font.family resolves it from the system fontconfig and
  // falls back to the default family when not installed.
  readonly property string readerFontFamily: "Noto Sans"

  // --- prayer times (singleton service) --------------------------------------
  // The bar instantiates one Shell panel per monitor, but adhan audio and
  // prayer notifications must fire once per process. That pipeline lives in
  // PrayerService.qml — an Omarchy service singleton (one instance per plugin
  // id) — and this panel forwards reads through it so every monitor shows the
  // same state.

  property var prayerService: null

  property var prayerTimes: root.prayerService ? root.prayerService.prayerTimes : ({})
  property int prayerTick: root.prayerService ? root.prayerService.prayerTick : 0
  property bool soundPlaying: root.prayerService ? root.prayerService.soundPlaying : false

  property bool adhanEnabled   // persisted — user opts in
  onAdhanEnabledChanged: root.pushToPrayerService()

  function stopAdhan() {
    if (root.prayerService) root.prayerService.stopAdhan()
  }

  // Resolve the service singleton. `bar` (and thus `bar.shell`) is injected by
  // BarWidget.qml after this panel loads, and the service may not exist yet on
  // the first call, so retry until it resolves.
  function resolvePrayerService() {
    if (root.prayerService) return true
    if (!root.bar || !root.bar.shell) return false
    var svc = root.bar.shell.firstPartyServiceFor("quran")
    if (svc) root.prayerService = svc
    return !!svc
  }

  function schedulePrayerServiceResolve() {
    Qt.callLater(function() {
      if (!root.resolvePrayerService()) prayerServiceRetry.start()
    })
  }

  onBarChanged: root.schedulePrayerServiceResolve()

  // Push UI locale + persisted adhan preference into the singleton. Re-pushed
  // when the service resolves so notification text follows the active language.
  function pushToPrayerService() {
    if (!root.prayerService) return
    root.prayerService.language = root.language
    root.prayerService.adhanEnabled = root.adhanEnabled
  }

  onPrayerServiceChanged: root.pushToPrayerService()
  onLanguageChanged: root.pushToPrayerService()

  Timer {
    id: prayerServiceRetry
    interval: 1000
    repeat: true
    running: false
    onTriggered: { if (root.resolvePrayerService()) prayerServiceRetry.stop() }
  }

  // --- paths ---
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/settings"
  readonly property string stateHelperPath: Model.fileUrlToPath(Qt.resolvedUrl("bin/omarchy-statefile"))

  // --- data loading ---
  FileView {
    path: Model.fileUrlToPath(Qt.resolvedUrl("data/quran.json"))
    printErrors: false
    onLoaded: {
      try { root.quran = JSON.parse(text()) } catch (e) { root.quran = null }
      stateFile.reload()
    }
    onLoadFailed: {
      root.quran = null
      stateFile.reload()
    }
  }

  // --- state persistence ---
  StateFile {
    id: stateFile
    path: root.stateDir + "/quran-state.json"
    helperPath: root.stateHelperPath
    onRestored: function(parsed) {
      if (parsed && typeof parsed === "object") {
        if (typeof parsed.surahId !== "number" && typeof parsed.surah === "number") parsed.surahId = parsed.surah
        if (typeof parsed.ayahN !== "number" && typeof parsed.ayah === "number") parsed.ayahN = parsed.ayah
        if (typeof parsed.surahId === "number" && Quran.surahById(parsed.surahId)) root.surah = parsed.surahId
        if (typeof parsed.ayahN === "number" && parsed.ayahN >= 1) root.ayah = parsed.ayahN
        var da = parsed.dailyAyat
        if (da && typeof da === "object" && typeof da.date === "string"
          && da.reference && typeof da.reference.surahId === "number"
          && Quran.surahById(da.reference.surahId)
          && da.reference.ayahN >= 1) {
          root.dailyAyat = {
            date: da.date, reference: da.reference,
            arabic: da.arabic || "", english: da.english || "",
            referenceLabel: da.referenceLabel || ""
          }
        }
        if (typeof parsed.language === "string"
          && (parsed.language === "english" || parsed.language === "arabic" || parsed.language === "both"))
          root.language = parsed.language
        if (typeof parsed.adhanEnabled === "boolean") root.adhanEnabled = parsed.adhanEnabled
      }
      root.stateReady = true
      root.applyRestoredState()
    }
    onFailed: { root.stateReady = true; root.applyRestoredState() }
  }

  StateFile {
    id: tabStateFile
    path: root.stateDir + "/quran-tab-state.json"
    helperPath: root.stateHelperPath
    onRestored: function(parsed) {
      root.tabStateLoaded = true
      var tab = (parsed && ["home", "quran", "hadith"].indexOf(parsed.tab) !== -1)
        ? parsed.tab : "home"
      Qt.callLater(function() { root.setPage(tab) })
    }
    onFailed: {
      root.tabStateLoaded = true
      Qt.callLater(function() { root.setPage("home") })
    }
  }

  Component.onCompleted: {
    tabStateFile.reload()
    root.schedulePrayerServiceResolve()
    // Defensive: if StateFile fails to trigger onRestored/onFailed (rare),
    // ensure the home page is always loaded.
    if (!root.tabStateLoaded) {
      root.tabStateLoaded = true
      Qt.callLater(function() { root.setPage("home") })
    }
  }

  function persistState() {
    if (!root.stateReady) return
    stateFile.setText(JSON.stringify({
      surahId: root.surah, ayahN: root.ayah,
      dailyAyat: root.dailyAyat, language: root.language,
      adhanEnabled: root.adhanEnabled
    }))
  }

  function saveTabState() {
    if (!root.tabStateLoaded) return
    tabStateFile.setText(JSON.stringify({ tab: root.currentPage }))
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: { if (root.opened) root.persistState() }
  }

  function applyRestoredState() {
    if (!root.quran || !root.stateReady) return
    root.ensureVerseOfDay()
  }

  function onReaderPositionChanged() {
    if (!quranPage) return
    root.surah = quranPage.surah
    root.ayah = quranPage.ayah
    saveTimer.restart()
  }

  function open() {
    root.controller.show()
    Qt.callLater(function() { root.ensureVerseOfDay() })
    Qt.callLater(function() { root.hadithPageLoaded = true })
  }

  function close() {
    saveTimer.stop()
    root.persistState()
    if (hadithPage && typeof hadithPage.saveState === "function") hadithPage.saveState()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function ensureVerseOfDay() {
    if (!root.service || !root.quran) return
    var key = root.service.todayKey || ""
    if (key === "") return
    var cached = root.dailyAyat
    if (cached && cached.date === key && cached.reference) {
      root.service.todayReference = cached.referenceLabel
      return
    }
    var result = Model.dailyAyahReference(root.quran, new Date(key))
    if (result && result.reference) {
      root.dailyAyat = {
        date: key, reference: result.reference,
        arabic: result.arabic, english: result.english,
        referenceLabel: result.referenceLabel
      }
      root.service.todayReference = result.referenceLabel
      root.persistState()
    }
  }

  function setPage(page) {
    if (["home", "quran", "hadith"].indexOf(page) === -1) return
    if (root.currentPage === page) return
    // Snapshot the reader position BEFORE visibility swap destroys binding.
    var savedSurah = root.surah
    var savedAyah = root.ayah
    root.currentPage = page
    // Defensive fallback for the hadith lazy-loader race: open()'s deferred
    // Qt.callLater assignment can run after a restored tab state calls setPage("hadith").
    if (page === "hadith" && !root.hadithPageLoaded) root.hadithPageLoaded = true
    root.saveTabState()
    // Restore last-read position on the Quran page.
    if (page === "quran" && Quran.surahById(savedSurah)
        && typeof quranPageInst.openSurahAyah === "function") {
      quranPageInst.openSurahAyah(savedSurah, savedAyah)
    }
    // Carry a quick-search query from HomePage into the Quran reader. Deferred
    // so openSurahAyah() above has settled into read mode before the search
    // flips it back to results.
    if (page === "quran" && root.pendingSearch) {
      var query = root.pendingSearch
      root.pendingSearch = ""
      Qt.callLater(function() {
        if (quranPageInst && quranPageInst.quranTab) quranPageInst.quranTab.startSearch(query)
      })
    }
  }

  KeyboardPanel {
    id: keyboardPanel
    anchorItem: root.anchorItem
    owner: root.panelOwner
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: 0
    borderSpec: ({
      color: root.accentColor,
      widths: {
        top: Style.space(1),
        right: Style.space(1),
        bottom: Style.space(1),
        left: Style.space(1)
      }
    })
    contentWidth: keyboardPanel.fittedContentWidth(Style.space(520))
    contentHeight: keyboardPanel.fittedContentHeight(
      bodyColumn.implicitHeight + Style.spacing.lg * 2,
      Style.space(640)
    )

    Item {
      anchors.fill: parent

      Keys.onPressed: function(event) {
        if (event.modifiers & Qt.ControlModifier) {
          if (event.key === Qt.Key_1) root.setPage("home")
          else if (event.key === Qt.Key_2) root.setPage("quran")
          else if (event.key === Qt.Key_3) root.setPage("hadith")
          else return
          event.accepted = true
        }
      }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        blocked: (quranPage && quranPage.searchFocused) || (hadithPage && hadithPage.searchFocused)
        onCloseRequested: root.close()
        onMoveRequested: function(dx, dy) {
          var delta = dy || dx  // vertical first, horizontal fallback
          if (root.currentPage === "quran" && quranPage) {
            quranPage.quranTab.stepAyah(delta)
          } else if (root.currentPage === "hadith" && hadithPage) {
            hadithPage.hadithTab.stepHadith(delta)
          } else if (root.currentPage === "home" && homePage) {
            homePage.stepAyah(delta)
          }
        }
        onActivateRequested: function() {
          if (root.currentPage === "quran" && quranPage) {
            quranPage.quranTab.activate()
          } else if (root.currentPage === "hadith" && hadithPage) {
            hadithPage.hadithTab.activate()
          } else if (root.currentPage === "home" && homePage) {
            homePage.activate()
          }
        }
        onTabRequested: function(direction) {
          if (bar && typeof bar.switchPanelFrom === "function")
            bar.switchPanelFrom(root.panelOwner, direction)
        }

        Rectangle {  // full-bleed background
          anchors.fill: parent
          z: -2
          color: root.panelBackground
        }

        MouseArea {  // background click returns focus
          anchors.fill: parent
          z: -1
          onPressed: keyCatcher.forceActiveFocus()
        }

        Flickable {
          id: bodyScroll
          anchors.fill: parent
          clip: true
          contentWidth: width
          contentHeight: bodyColumn.implicitHeight + Style.spacing.lg * 2
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

          Column {
            id: bodyColumn
            x: Style.spacing.lg
            y: Style.spacing.lg
            width: bodyScroll.width - Style.spacing.lg * 2
            spacing: Style.spacing.sm

            BasmalaHeader {
              width: parent.width
              accentColor: root.accentColor
              contentForeground: root.contentForeground
              panelBackground: root.panelBackground
              fontFamily: root.fontFamily
              arabicFontFamily: root.arabicFontFamily
              language: root.language
              onLanguageSelected: function(lang) { root.language = lang }
            }

            MedallionBar {
              width: parent.width
              currentPage: root.currentPage
              language: root.language
              accentColor: root.accentColor
              mutedForeground: root.mutedForeground
              contentForeground: root.contentForeground
              fontFamily: root.fontFamily
              onPageSelected: function(page) { root.setPage(page) }
            }

            Rectangle {  // gold divider
              width: parent.width; height: Style.space(1)
              color: root.borderColor
            }

            // Pages — Home and Quran instantiate eagerly; HadithPage loads lazily via Loader.
            // Visibility toggles via root.currentPage.
            HomePage {
              id: homePageInst
              visible: root.currentPage === "home"
              shell: root
            }

            QuranPage {
              id: quranPageInst
              width: parent.width
              visible: root.currentPage === "quran"
              shell: root
            }

            Loader {
              id: hadithPageLoader
              width: parent.width
              visible: root.currentPage === "hadith"
              active: root.hadithPageLoaded
              sourceComponent: hadithPageComp
            }

            Component {
              id: hadithPageComp
              HadithPage {
                width: parent ? parent.width : 0
                visible: root.currentPage === "hadith"
                shell: root
              }
            }
          }
        }
      }
    }
  }
}
