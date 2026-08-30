// components/QuranTab.qml — Quran reader + search.
//
// Three modes: "read" (ayahs of the current surah in a scrollable list),
// "search" (text-search results computed off-thread by QuranSearchWorker.js), and
// "surahs" (browse all 114 surahs). The parsed quran.json arrives via the
// `quran` property, injected by Shell.qml (named `quran`, not `data`, because
// `data` is the reserved default property on QQuickItem). A reference query
// ("2:255", "al-baqarah 255") jumps straight to the ayah; anything else runs
// as a case-insensitive text search over the Arabic + English text.
//
// A QuranReaderHeader with an ayah PositionBar sits above the verse list, a
// QuranSearchField sits up top, and transparent result/surah rows gain a
// surface-green hover fill and a gold accent for the current/selected item.

import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "../Quran.js" as Quran
import "../Model.js" as Model
import "../search.js" as Search
import "../search-flight.js" as SearchFlight
import "../i18n.js" as I18n

Column {
  id: root
  width: parent.width
  spacing: Style.spacing.sm

  // i18n helpers — __() for plain strings, _() for templates with {placeholders}.
  function __(key) { return I18n.get(key, root.language) }
  function _(key, args) { return I18n.template(key, root.language, args || {}) }

  // Injected by Shell.qml.
  property var quran: null
  onQuranChanged: {
    // Load initial ayah data when the Quran object arrives, so the reader
    // shows content on the first mount (not only after navigating chapters).
    if (root.quran && root.currentAyahs.length === 0) {
      root.openSurahAyah(root.surah, root.ayah)
    }
  }

  required property color accentColor
  required property color hoverTint
  required property color selectionTint
  required property color contentForeground
  required property color mutedForeground
  required property color surfaceColor
  required property color borderColor
  required property string fontFamily
  required property string readerFontFamily
  required property string arabicFontFamily
  required property string language
  required property Item keyCatcher
  required property real dimOpacity

  // mode: "read" | "search" | "surahs"
  property string mode: "read"

  property int surah: Quran.DEFAULT_SURAH
  property int ayah: Quran.DEFAULT_AYAH
  property string searchText
  // Search results stored in a ListModel so clear()+append() are batched
  // atomically as one paint cycle — avoids the JS-array crash where Array
  // replacement destroys delegates while QQuickItem::update() events are
  // still pending for the old delegates (QTBUG-80203).
  ListModel { id: resultModel }
  // Autocomplete suggestions for the current query, returned by the search
  // worker (reference targets first, then word-prefix matches). Cleared when
  // the field loses focus or the query changes.
  property var suggestions: []
  // Set to the last suggestion text accepted by applySuggestion; cleared once
  // the worker reply for that query arrives to suppress re-showing the dropdown.
  property string acceptedSuggestion
  // The reference ayah resolved by performSearch() (e.g. "2:255"), pinned as the
  // top result; null for plain text queries. Kept separate from the resultModel so
  // onMessage can tell a true reference pin apart from a stale 1-item array.
  property var pinnedAyah: null
  property string statusText
  property var currentAyahs: []
  property int selectedIndex
  // Incremented by performSearch whenever the model is set directly (without
  // waiting for a worker reply). The worker dispatch stores this value; onMessage
  // skips model updates when the generation has advanced — prevents a stale
  // worker reply from re-clearing the model after performSearch already set it.
  property int searchGeneration

  // Lazy pagination — workers return all results, but we reveal them 7 at a
  // time to avoid dumping 100+ delegates in one paint cycle. Bible pattern.
  readonly property int maxResults: Search.DEFAULT_MAX_RESULTS   // shared backend cap from search.js
  readonly property int pageSize: 7        // 7 heavens, 7 tawaf, 7 verses of Al-Fatiha
  property var pendingResults: []          // unrevealed { surahId, ayahN, ar, en }
  property int revealedCount
  property bool truncated           // backend hit maxResults cap

  // Owns clipboard copy + transient "Copied — ..." feedback (shared helper).
  QuranCopyHelper { id: copyHelper }

  // True while the search field holds activeFocus; Shell.qml blocks the key
  // catcher so arrow navigation stays live only when the field is unfocused.
  readonly property bool searchFocused: searchField.activeFocus

  // Fixed reader viewport height (mirrors the Bible's readerHeight) so the
  // tab sizes naturally inside Shell.qml's scrollable body column.
  readonly property int readerHeight: Style.space(360)

  // Number of ayahs in the current surah, or 0 until the data is loaded.
  readonly property int ayahCount: root.currentAyahs ? root.currentAyahs.length : 0

  // --- navigation ------------------------------------------------------------

  function openSurahAyah(surahId, ayahNum) {
    if (!Quran.surahById(surahId)) return
    root.surah = surahId
    root.ayah = Quran.clampAyah(surahId, ayahNum || 1)
    root.currentAyahs = root.quran ? Model.ayahsFor(root.quran, root.surah) : []
    // Clear transient search state and switch to reader; searchField.text is
    // preserved so the user can resume searching from the same query.
    root.resetSearchState()
    root.suggestions = []
    root.pinnedAyah = null
    root.mode = "read"
    // Scroll to the target ayah after the search-to-read mode switch settles.
    // Double callLater: the first lets the view switch into read mode; the
    // second fires after the reader ListView is laid out and sized.
    Qt.callLater(function() { Qt.callLater(function() { ayahList.positionViewAtIndex(root.ayah - 1, ListView.Contain) }) })
  }

  function stepSurah(delta) {
    var next = delta > 0 ? Quran.nextSurah(root.surah) : Quran.prevSurah(root.surah)
    root.openSurahAyah(next, 1)
  }

  function stepAyah(delta) {
    // In search mode, Up/Down moves the result selection; otherwise it pages
    // the ayah within the current surah.
    if (root.mode === "search" && resultModel.count > 0) {
      root.moveSelection(delta)
      return
    }
    if (root.ayahCount === 0) return
    var newAyah = root.ayah + delta
    if (newAyah >= 1 && newAyah <= root.ayahCount) {
      root.ayah = newAyah
      ayahList.positionViewAtIndex(root.ayah - 1, ListView.Contain)
    }
  }

  // Enter/Space from the panel key catcher: open the selected search result,
  // or copy the current ayah in read mode.
  function activate() {
    if (root.mode === "search" && resultModel.count > 0) {
      var r = resultModel.get(root.selectedIndex)
      if (r) root.openSurahAyah(r.surahId, r.ayahN)
      return
    }
    var m = root.currentAyahs[root.ayah - 1]
    if (m) root.copyAyah(m)
  }

  // shared logic — keep in sync with HadithTab.moveSelection: only the result
  // ListView id differs (resultList vs searchResultsList).
  function moveSelection(delta) {
    if (resultModel.count === 0) return
    root.selectedIndex = Math.max(0, Math.min(resultModel.count - 1, root.selectedIndex + delta))
    // Reveal next page when keyboard-navigating near the end of what's shown.
    if (root.selectedIndex >= resultModel.count - 3 && resultModel.count < root.pendingResults.length)
      root.revealMore()
    if (resultList.visible) resultList.positionViewAtIndex(root.selectedIndex, ListView.Center)
  }

  function copyAyah(m) {
    var ref = Quran.formatRefLocalized(root.surah, m.n, root.language)
    copyHelper.copy(Model.arabicFor(root.quran, root.surah, m.n, m.ar), m.en || "",
                    root.language, ref, ref + "\n\n" + __("copy.footer"))
  }

  // --- search ----------------------------------------------------------------

  // The worker caches the parsed data after the first message that carries it,
  // so subsequent searches only send the query.
  property bool workerSeeded

  // Single-flight dispatch: at most one query is in the worker at a time, and
  // the trailing query typed while one is in flight is dispatched once the
  // reply lands — never dropped (mirrors the Bible's outstanding/pendingQuery).
  // Per-tab search-flight state instance; SearchFlight module logic is shared.
  property var flight: SearchFlight.makeState()

  WorkerScript {
    id: searchWorker
    source: "QuranSearchWorker.js"
    onMessage: function(msg) {
      // Decrement before the stale check so the count can never wedge, then
      // dispatch the query typed while this one was in flight.
      var current = SearchFlight.ack(root.flight, msg.query, root.searchText)
      root.flushSearchPending()
      if (!current) return  // stale reply for an older query
      // Skip model update when performSearch has resolved the same query
      // directly after this dispatch was sent — avoids a second model
      // reset colliding with the one already queued via Qt.callLater.
      if (root.searchGeneration > (msg.searchGeneration || 0)) {
        return
      }
      // Collect the worker's text-search results. The reference result was
      // already pinned by performSearch() (if any), so prepend it and dedupe.
      var fresh = msg.results || []
      var pinned = root.pinnedAyah ? [root.pinnedAyah] : []
      var seen = {}
      if (pinned.length === 1) {
        seen[String(pinned[0].surahId) + ":" + pinned[0].ayahN] = true
      }
      var merged = pinned.slice()
      for (var i = 0; i < fresh.length; i++) {
        if (!seen[String(fresh[i].surahId) + ":" + fresh[i].ayahN]) {
          merged.push(fresh[i])
          seen[String(fresh[i].surahId) + ":" + fresh[i].ayahN] = true
        }
      }
      root.suggestions = (msg.query !== root.acceptedSuggestion) ? (msg.suggestions || []) : []
      root.acceptedSuggestion = ""
      root.pendingResults = merged
      root.truncated = merged.length >= root.maxResults
      root.revealedCount = 0
      root.selectedIndex = 0
      root.mode = "search"
      root.statusText = merged.length === 0
        ? _("search.noMatches", {query: root.searchText})
        : _("search.matches", {n: String(merged.length),
            // English "s" plural — Arabic template drops {suffix}, so only English is affected
            suffix: (merged.length === 1 ? "" : "s") + (root.truncated ? "+" : "")})
      // Defer model reset so Qt can flush pending delegate tear-down events
      // before we clear and repopulate (avoids CallQmlContextPropertyLookup SIGTRAP).
      Qt.callLater(function() {
        resultModel.clear()
        root.revealMore()
        resultList.positionViewAtIndex(0, ListView.Center)
      })
    }
  }

  Timer {
    id: searchTimer
    interval: 160
    repeat: false
    onTriggered: root.performSearch()
  }

  // Append the next pageSize pending results into resultModel (Bible pattern).
  // shared logic — keep in sync with HadithTab.revealMore: only the appended row
  // schema differs (surahId/ayahN/ar/en here vs hadithIdx there).
  function revealMore() {
    var end = Math.min(root.pendingResults.length, root.revealedCount + root.pageSize)
    for (var i = root.revealedCount; i < end; i++) {
      var r = root.pendingResults[i]
      resultModel.append({ surahId: r.surahId, ayahN: r.ayahN, ar: r.ar || "", en: r.en || "" })
    }
    root.revealedCount = end
  }

  // Reset transient search state — shared by openSurahAyah, performSearch (empty
  // query) and clearSearch. shared logic — keep in sync with
  // HadithTab.resetSearchState: Quran also clears statusText (Hadith derives it).
  function resetSearchState() {
    resultModel.clear()
    root.pendingResults = []
    root.revealedCount = 0
    root.truncated = false
    root.statusText = ""
    SearchFlight.clear(root.flight)
  }

  // Entry point for the HomePage quick search (via Shell.setPage). Sets the
  // field text and searches immediately — no declarative text binding exists
  // because it would be broken permanently the first time the user types.
  function startSearch(query) {
    searchField.text = query
    searchTimer.stop()
    root.searchText = query
    root.performSearch()
    searchField.forceActiveFocus()
  }

  function performSearch() {
    if (!root.searchText || !root.quran) {
      root.pinnedAyah = null
      root.resetSearchState()
      return
    }
    // A reference ("2:255" / "al-baqarah 255" / "2") is resolved and pinned as
    // the top search result, so the user sees that ayah's text in the results
    // list. The worker still runs, but with the *remaining* text words so
    // that a bare "3:" returns text-search matches for surah-3 content instead
    // of the literal two-character string "3:" (which appears nowhere in the
    // Quran text). If nothing remains, the worker searches for the surah name.
    var byRef = Search.searchByReference(root.quran, root.searchText)
    if (byRef.length === 1) {
      root.pinnedAyah = byRef[0]
      root.searchGeneration++
      root.selectedIndex = 0
      root.mode = "search"
      root.statusText = __("search.searching")
    } else {
      // Keep the current results visible until the worker reply atomically
      // replaces the model. ListModel.clear()+append() are batched as one
      // paint cycle — safe even with pending delegate update() effects.
      root.pinnedAyah = null
      root.statusText = __("search.searching")
    }
    // Single-flight: queue the query and dispatch only when nothing is in
    // flight, so a burst of debounced queries never piles work into the worker.
    var enqueued = SearchFlight.enqueue(root.flight, root.searchText)
    if (enqueued) root.flushSearchPending()
  }

  function flushSearchPending() {
    var query = SearchFlight.takePending(root.flight)
    if (query === "") return
    if (!root.pinnedAyah) {
      root.statusText = __("search.searching")
      root.mode = "search"
    }
    searchWorker.sendMessage(root.buildWorkerMessage(query))
    SearchFlight.markSent(root.flight)
  }

  // Build the worker message for a query: strip the reference prefix so the
  // worker searches for useful words rather than the literal ref string
  // (e.g. "3: mercy" → "mercy", "3:" → "3:"). The prefix is extracted *before*
  // the reference check, so a query like "2: mercy" — which parseReference
  // rejects for trailing free text — still resolves: "2:" pins Al-Baqarah 2:1,
  // "mercy" is the text term.
  function buildWorkerMessage(query) {
    var msg = { query: query, searchGeneration: root.searchGeneration }
    if (!root.workerSeeded) {
      msg.data = root.quran
      root.workerSeeded = true
    }
    var ref = query.match(/^\s*(\d+\s*:\s*\d*)\s*/) || query.match(/^\s*([a-zA-Z\-]+\s+\d+)\s*/)
    var refPortion = ref ? ref[1] : ""
    var afterRef = ref ? query.slice(ref[0].length).trim() : ""
    var byRef = refPortion ? Search.searchByReference(root.quran, refPortion) : []
    // When performSearch already resolved the query (e.g. "Al-Baqarah" via
    // parseReference) but the regex above didn't capture it (no digit match),
    // carry the pinned ayah forward so buildWorkerMessage uses the same ref.
    var isSurahName = false
    if (!ref && root.pinnedAyah && byRef.length === 0) {
      byRef = [root.pinnedAyah]
      isSurahName = true
    }
    if (byRef.length === 1) {
      if (afterRef === "") {
        if (isSurahName) {
          // Surah-name query ("Al-Baqarah"): search the whole Quran for
          // this text with IDF relevance, anchored by proximity to the
          // surah's first ayah so verses from this surah get a boost.
          msg.textQuery = query
          msg.proximityRef = { surahId: byRef[0].surahId, ayahN: 1 }
        } else if (/\d+:\d+/.test(refPortion.trim())) {
          // Full reference ("2:2"): proximity-ranked neighbors
          msg.textQuery = ""
          msg.proximityRef = { surahId: byRef[0].surahId, ayahN: byRef[0].ayahN }
        } else {
          // Surah-only digit ref ("2:"): all ayahs in that surah, ordered
          // in canonical position (not relevance-scored).
          msg.textQuery = String(byRef[0].surahId) + ":"
          var si = byRef[0].surahId - 1
          if (root.quran && root.quran.surahs && root.quran.surahs[si]) {
            msg.maxResults = root.quran.surahs[si].ayahs.length
          }
        }
      } else {
        msg.textQuery = afterRef
      }
    }
    return msg
  }

  function clearSearch() {
    root.searchText = ""
    // Set the field text directly (not just searchText): typing breaks the
    // text binding, so the field would keep stale text otherwise.
    searchField.text = ""
    root.resetSearchState()
    root.suggestions = []
    root.pinnedAyah = null
    root.selectedIndex = 0
    root.mode = "read"
  }

  // shared logic — keep in sync with HadithTab.applySuggestion
  function applySuggestion(sug) {
    root.suggestions = []
    // Reference suggestions carry the surah name (e.g. "Aal-i-Imran 3:6");
    // extract just the bare "N:M" reference so parseReference resolves it.
    // Word suggestions ("allah", "prayer") pass through unchanged.
    var bare = sug.match(/(\d+:\d+)$/)
    var text = bare ? bare[1] : sug
    root.acceptedSuggestion = text
    searchTimer.stop()   // suppress the onTextChanged → timer re-trigger
    searchField.text = text
    searchField.forceActiveFocus()
    root.performSearch()
  }

  // Wrap the search result's English text, highlighting query words with an
  // accent-colored tag for Text.RichText rendering.
  function highlightedResult(raw, query) {
    return Search.highlightQuery(String(raw).slice(0, 200), query, root.accentColor)
  }

  // --- layout ----------------------------------------------------------------

  QuranSearchField {
    id: searchField
    width: parent.width
    placeholderText: __("search.placeholder")
    hasResults: resultModel.count > 0
    closeGlyph: "\u2715"
    accentColor: root.accentColor
    contentForeground: root.contentForeground
    mutedForeground: root.mutedForeground
    surfaceColor: root.surfaceColor
    borderColor: root.borderColor
    fontFamily: root.fontFamily
    dimOpacity: root.dimOpacity
    keyCatcher: root.keyCatcher
    // shared logic — keep in sync with HadithTab's searchField wiring:
    // onTextChanged / onActiveFocusChanged / onNavigate differ only in the query
    // property name (searchText vs query).
    onTextChanged: {
      root.searchText = text
      if (text !== "") searchTimer.restart()
      else root.clearSearch()
    }
    onActiveFocusChanged: {
      if (activeFocus && text !== "") searchTimer.restart()
    }
    onNavigate: function(delta) { root.moveSelection(delta) }
  }

  // Autocomplete suggestions, shown below the search field while it has focus.
  SuggestionList {
    width: parent.width
    visible: searchField.activeFocus && root.suggestions.length > 0
    suggestions: root.suggestions
    surfaceColor: root.surfaceColor; hoverTint: root.hoverTint
    borderColor: root.borderColor; contentForeground: root.contentForeground; fontFamily: root.fontFamily
    onApplySuggestion: function(text) { root.applySuggestion(text) }
  }

  // ---- reader (read | surahs) --------------------------------------------
  Column {
    width: parent.width
    visible: root.mode === "read" || root.mode === "surahs"
    spacing: Style.spacing.sm
    topPadding: Style.spacing.lg

    QuranReaderHeader {
      title: Quran.formatRefLocalized(root.surah, root.ayah, root.language)
      subtitle: _("quran.ayahOf", {n: String(root.ayah), total: String(root.ayahCount)})
      positionValue: root.ayah
      positionMax: root.ayahCount
      positionLabelPrefix: __("quran.ayah")
      showExtraButton: true
      extraButtonActive: root.mode === "surahs"
      accentColor: root.accentColor
      hoverTint: root.hoverTint
      selectionTint: root.selectionTint
      contentForeground: root.contentForeground
      surfaceColor: root.surfaceColor
      fontFamily: root.fontFamily
      dimOpacity: root.dimOpacity
      keyCatcher: root.keyCatcher
      onJump: function(target) {
        root.ayah = target
        ayahList.positionViewAtIndex(root.ayah - 1, ListView.Contain)
      }
      onPrev: root.stepSurah(-1)
      onNext: root.stepSurah(1)
      onExtraClicked: root.mode = (root.mode === "surahs" ? "read" : "surahs")
    }

    QuranCopyFeedback {
      copyFeedback: copyHelper.feedback
      fontFamily: root.fontFamily
      accentColor: root.accentColor
    }

    // Guaranteed breathing room between the header and the verse list,
    // independent of whether copy feedback is showing.
    Item { width: parent.width; height: Style.space(16) }

    ListView {
      id: ayahList
      width: parent.width
      height: Math.min(root.readerHeight, ayahList.contentHeight)
      visible: root.mode === "read"
      clip: true
      model: root.currentAyahs
      spacing: Style.spacing.lg
      boundsBehavior: Flickable.StopAtBounds
      footer: Item { width: parent.width; height: Style.spacing.lg }
      QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

      // Track the center-most ayah so the PositionBar follows scrolling
      // (mirrors the Bible's verse-list scroll tracking).
      onContentYChanged: {
        var idx = ayahList.indexAt(0, ayahList.contentY + ayahList.height / 2)
        if (idx >= 0 && (idx + 1) !== root.ayah) root.ayah = idx + 1
      }

      // Clicks in the viewport below the last ayah land on the ListView
      // itself, which grabs them for drag detection and would leave the
      // search field focused. TapHandler passive-grabs so it clears focus
      // without blocking flicking.
      TapHandler {
        onTapped: root.keyCatcher.forceActiveFocus()
      }

      header: Item {
        width: ayahList.width
        height: basmalaText.text !== "" ? basmalaText.implicitHeight + Style.space(6) : 0

        Text {
          id: basmalaText
          width: parent.width
          text: root.quran ? Model.basmalaFor(root.quran, root.surah) : ""
          textFormat: Text.PlainText
          color: root.contentForeground
          font.family: root.arabicFontFamily
          font.pixelSize: Style.font.displayLarge
          horizontalAlignment: Text.AlignRight
          wrapMode: Text.WordWrap
        }
      }

      delegate: Item {
        required property var modelData
        readonly property bool selected: modelData.n === root.ayah
        width: ayahList.width
        height: ayahColumn.implicitHeight

        Rectangle {
          anchors.fill: parent
          color: selected ? root.selectionTint : "transparent"
          radius: Style.space(3)
        }

        Column {
          id: ayahColumn
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            width: parent.width
            visible: root.language !== "english"
            text: modelData.n + ". " + Model.arabicFor(root.quran, root.surah, modelData.n, modelData.ar)
            textFormat: Text.PlainText
            color: modelData.n === root.ayah ? root.accentColor : root.contentForeground
            font.family: root.arabicFontFamily
            font.pixelSize: Style.font.title
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            leftPadding: Style.space(6)
            rightPadding: Style.space(6)
          }

          Text {
            width: parent.width
            visible: root.language !== "arabic"
            text: modelData.en || ""
            textFormat: Text.PlainText
            color: root.contentForeground
            font.family: root.readerFontFamily
            font.pixelSize: Style.font.heading
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.keyCatcher.forceActiveFocus()
            root.ayah = modelData.n
            root.copyAyah(modelData)
          }
        }
      }
    }

    ListView {
      id: surahList
      width: parent.width
      height: Math.min(root.readerHeight, surahList.contentHeight)
      visible: root.mode === "surahs"
      clip: true
      model: Quran.SURAHS
      spacing: Style.spacing.xs
      boundsBehavior: Flickable.StopAtBounds
      QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

      delegate: Item {
        required property var modelData
        width: surahList.width
        height: Style.space(32)

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: surahMouse.containsMouse ? root.hoverTint : root.surfaceColor
          border.width: Style.space(1)
          border.color: root.borderColor
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.sm
          anchors.right: parent.right
          anchors.rightMargin: Style.spacing.sm
          anchors.verticalCenter: parent.verticalCenter
          text: root.language === "arabic"
                 ? modelData.id + ". " + modelData.name_ar
                 : modelData.id + ". " + modelData.name_translit + " (" + modelData.name_ar + ")"
          textFormat: Text.PlainText
          color: modelData.id === root.surah ? root.accentColor : root.contentForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: modelData.id === root.surah
          elide: Text.ElideRight
        }

        MouseArea {
          id: surahMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.keyCatcher.forceActiveFocus()
            root.openSurahAyah(modelData.id, 1)
          }
        }
      }
    }
  }

  // ---- search results -----------------------------------------------------
  Column {
    width: parent.width
    visible: root.mode === "search"
    spacing: Style.spacing.md

    QuranStatusRow {
      visible: root.statusText !== ""
      label: root.statusText
      showHint: resultModel.count > 0
      language: root.language
      contentForeground: root.contentForeground
      mutedForeground: root.mutedForeground
      dimOpacity: root.dimOpacity
      fontFamily: root.fontFamily
    }

    ListView {
      id: resultList
      width: parent.width
      visible: resultModel.count > 0
      height: Math.min(Style.space(320), Math.max(Style.space(96), contentHeight))
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: resultModel
      spacing: Style.spacing.xs

      // Reveal next page when 80 % through the scrollable area (20 % from bottom).
      onContentYChanged: {
        if (Search.shouldRevealMore(contentY, contentHeight, height))
          root.revealMore()
      }

      // Wrapper Item: QuranResultCard declares required properties, which in
      // Qt 5.15 disables ListView context injection (index / roles) on the
      // delegate root. The plain Item receives them and passes them down.
      delegate: Item {
        width: ListView.view.width
        height: resultCard.height

        QuranResultCard {
          id: resultCard
          width: parent.width
          rowIndex: index
          itemCount: resultModel.count
          selected: index === root.selectedIndex
          language: root.language
          accentColor: root.accentColor
          contentForeground: root.contentForeground
          mutedForeground: root.mutedForeground
          surfaceColor: root.surfaceColor
          borderColor: root.borderColor
          hoverTint: root.hoverTint
          selectionTint: root.selectionTint
          fontFamily: root.fontFamily
          arabicFontFamily: root.arabicFontFamily

          title: Quran.formatRefLocalized(surahId, ayahN, root.language)
          arabic: root.language !== "english" ? ar : ""
          english: root.language !== "arabic" ? root.highlightedResult(en, root.searchText) : ""
          englishRich: true
          goHint: __("quran.goTo")
          goHintAccent: ayahN === root.ayah

          onEntered: function(i) { root.selectedIndex = i }
          onClicked: root.openSurahAyah(surahId, ayahN)
        }
      }
    }
  }
}
