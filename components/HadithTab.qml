// components/HadithTab.qml — Hadith browser.
//
// Catechism-style reader over sixteen pre-merged hadith collections bundled as
// data/hadith/{collection}.json (Pre-merged eng + ara editions in compact format
// (n/t/a/g): a flat hadiths array plus a chapters table). A single FileView
// loads the active collection on demand; read mode steps hadiths (Up/Down) and
// chapters (Left/Right). The ☰ button cycles the picker through read → chapters
// → collections (the sixteen-collection list) and back, and the last
// {collection, hadithNumber} is persisted to quran-hadith-state.json.
//
// Layout: a single content column. The search field is always visible at the
// top: typing runs a debounced in-memory search (results replace the reader),
// clearing returns to read mode.

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import "../search.js" as Search
import "../Model.js" as Model
import "../search-flight.js" as SearchFlight
import "../i18n.js" as I18n

Column {
  id: root
  width: parent.width

  // i18n helpers — __() for plain strings, _() for templates with {placeholders}.
  function __(key) { return I18n.get(key, root.language) }
  function _(key, args) { return I18n.template(key, root.language, args || {}) }

  // The collection's ~13MB JSON is loaded on first open of the Hadith page
  // (same FileView pattern as quranFile). HadithPage is lazy-loaded at the
  // Shell level, so this is only parsed on first open, not panel startup.
  Component.onCompleted: hadithStateFile.reload()

  // Injected by Shell.qml.
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
  required property Item keyCatcher
  required property real dimOpacity

  // mode: "read" | "chapters" | "collections"
  property string mode: "read"

  // language: "both" | "english" | "arabic" — which text to show in the hadith
  // delegate and include in the copy payload. Owned by Shell.qml (persisted in
  // quran-state.json) and injected here.
  required property string language

  // Active collection (edition id, e.g. "bukhari") and current position.
  property string collectionId: "bukhari"
  property int hadithIndex
  // Edition object { name, chapters, hadiths }, null until loaded.
  property var edition: null
  // Hadith number to land on once the in-flight edition resolves.
  property int targetNumber: 1

  // When true, onEditionLoaded() lands on the last hadith instead of targetNumber.
  // Set by stepCollection(-1) so stepping backwards into a collection opens at
  // the end (Right then steps into the first chapter naturally).
  property bool openAtLastHadith
  // Mode to switch to after the in-flight edition loads ("read" | "chapters").
  property string modeAfterLoad: "read"

  // Search state (always-visible field; derived from the query, not a mode).
  property string query
  property int selectedIndex
  // Autocomplete suggestions from the search worker (word-prefix matches).
  property var suggestions: []
  property string acceptedSuggestion
  // True while the worker is processing a query — shown as "Searching…".
  property bool searchPending

  // Lazy pagination — workers return all results, revealed 7 at a time
  // (Bible pattern). resultModel holds revealed entries; pendingResults
  // holds the unrevealed remainder.
  readonly property int maxResults: Search.DEFAULT_MAX_RESULTS   // shared backend cap from search.js
  readonly property int pageSize: 6       // 6 articles of faith (iman mufassal)
  property var pendingResults: []          // unrevealed { index } from worker
  property int revealedCount
  property bool truncated           // backend hit maxResults cap
  ListModel { id: resultModel }

  // Owns clipboard copy + transient "Copied — ..." feedback (shared helper).
  QuranCopyHelper { id: copyHelper }

  // The worker caches the normalized hadith array after the first message that
  // carries it, re-seeded whenever the active collection changes so subsequent
  // searches only send the query.
  property string seededCollection

  // Single-flight dispatch: at most one query is in the worker at a time, and
  // the trailing query typed while one is in flight is dispatched once the
  // reply lands — never dropped. Per-tab search-flight state instance;
  // SearchFlight module logic is shared.
  property var flight: SearchFlight.makeState()

  // True while the search field holds activeFocus; Shell.qml blocks the key
  // catcher so arrow navigation stays live only when the field is unfocused.
  readonly property bool searchFocused: searchField.activeFocus

  // True while search results own the view; explicit (not derived from query
  // text) so opening a result can keep the query in the field, as QuranTab does.
  property bool searchActive

  // Fixed reader viewport height (mirrors the Bible's readerHeight).
  readonly property int readerHeight: Style.space(360)

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/settings"
  readonly property string stateHelperPath: Model.fileUrlToPath(Qt.resolvedUrl("../bin/omarchy-statefile"))

  // The sixteen collections that resolve to bundled data/hadith/{id}.json files.
  // Single source of truth: Model.COLLECTIONS, in traditional Sunni order.
  readonly property var collections: Model.COLLECTIONS

  // --- derived view state ----------------------------------------------------

  readonly property var hadiths: root.edition ? root.edition.hadiths : []
  readonly property var chapters: root.edition ? root.edition.chapters : []
  readonly property int totalHadiths: root.edition ? root.edition.hadiths.length : 0
  readonly property string collectionName:
    Model.collectionName(root.collectionId, root.language)

  readonly property var currentHadith:
    (root.totalHadiths > 0 && root.hadithIndex >= 0 && root.hadithIndex < root.totalHadiths)
      ? root.hadiths[root.hadithIndex] : null

  // Index of the current collection in Model.COLLECTIONS, for cross-collection
  // navigation when the user steps past the last/first chapter or hadith.
  readonly property int collectionIndex: Model.collectionIndex(root.collectionId)

  // 1-based position of the current hadith within its chapter, and the total
  // hadiths in that chapter — used by the position bar (Bible catechism pattern).
  readonly property int positionInChapter: {
    var ci = root.currentChapterIndex
    if (ci < 0) return 1
    var start = root.chapters[ci].startIndex
    return root.hadithIndex - start + 1
  }

  readonly property int currentChapterLength: {
    var ci = root.currentChapterIndex
    if (ci < 0) return 0
    var start = root.chapters[ci].startIndex
    var end = (ci + 1 < root.chapters.length)
      ? root.chapters[ci + 1].startIndex
      : root.totalHadiths
    return end - start
  }

  readonly property int currentChapterStart: {
    var ci = root.currentChapterIndex
    return ci >= 0 ? root.chapters[ci].startIndex : 0
  }

  readonly property int currentChapterEnd:
    root.currentChapterStart + root.currentChapterLength - 1

  // Index of the chapter containing the current hadith (-1 for prefatory notes
  // in the unnamed book 0, and before the edition loads).
  readonly property int currentChapterIndex:
    root.currentHadith ? root.currentHadith.chapterIndex : -1

  readonly property string currentChapterName:
    (root.currentHadith && root.currentHadith.book) ? root.currentHadith.book : root.collectionName

  readonly property string currentChapterNameAr:
    Model.localizedName(currentChapterName,
      (root.currentHadith && root.currentHadith.book_ar) || "",
      root.language)

  readonly property string headerTitle: {
    if (root.mode === "chapters") return _("hadith.chaptersOf", {name: root.collectionName})
    if (root.mode === "collections") return __("hadith.collections")
    return root.currentChapterNameAr || root.collectionName
  }

  readonly property string headerSubtitle: {
    if (root.mode === "chapters") return _("hadith.nChapters", {n: String(root.chapters.length)})
    if (root.mode === "collections") return _("hadith.nCollections", {n: String(root.collections.length)})
    if (root.currentChapterLength <= 0) return root.collectionName
    return _("hadith.ofChapter", {collection: root.collectionName, pos: String(root.positionInChapter), len: String(root.currentChapterLength)})
  }

  readonly property string searchStatus: {
    if (root.searchPending) return __("search.searching")
    if (root.query.trim() === "") return ""
    if (resultModel.count > 0) {
      // Total hit count from pendingResults to show the true number, not just revealed.
      var total = root.pendingResults.length
      // English "s" plural — Arabic template drops {suffix}, so only English is affected
      return _("search.matches", {n: String(total), suffix: (total === 1 ? "" : "s") + (root.truncated ? "+" : "")})
    }
    return _("search.noMatches", {query: root.query})
  }

  // --- data / state files ----------------------------------------------------

  // Loads the active collection's bundled JSON. The path is a binding to
  // collectionId (matching Shell.qml's working quranFile pattern), so the
  // ~13MB bukhari.json is loaded on first open of the Hadith page.
  FileView {
    path: Model.fileUrlToPath(Qt.resolvedUrl("../data/hadith/" + root.collectionId + ".json"))
    printErrors: false
    onLoaded: {
      try {
        var obj = JSON.parse(text())
        root.onEditionLoaded(obj)
      } catch (e) {
        root.onEditionLoadFailed()
      }
    }
    onLoadFailed: root.onEditionLoadFailed()
  }

  StateFile {
    id: hadithStateFile
    path: root.stateDir + "/quran-hadith-state.json"
    helperPath: root.stateHelperPath
    onRestored: function(parsed) {
      if (parsed && typeof parsed === "object" && parsed.collection
        && root.isKnownCollection(parsed.collection)) {
        var sameCollection = (root.collectionId === parsed.collection)
        root.collectionId = parsed.collection
        root.targetNumber = (typeof parsed.hadithNumber === "number" && parsed.hadithNumber >= 1)
          ? parsed.hadithNumber : 1
        // If collectionId didn't change the FileView won't reload, so
        // onEditionLoaded() already ran with the old targetNumber=1.
        // Reposition now on the already-loaded edition.
        if (sameCollection && root.edition && root.totalHadiths > 0) {
          root.positionAtNumber(root.targetNumber)
        }
      }
    }
    onFailed: function() {
      root.collectionId = "bukhari"
    }
  }

  Timer {
    id: searchTimer
    interval: 160
    repeat: false
    onTriggered: root.performSearch()
  }

  WorkerScript {
    id: hadithSearchWorker
    source: "HadithSearchWorker.js"
    onMessage: function(msg) {
      // Decrement before the stale check so the count can never wedge, then
      // dispatch the query typed while this one was in flight.
      var current = SearchFlight.ack(root.flight, msg.query, root.query)
      root.flushSearchPending()
      // Ignore stale replies for an older query.
      if (!current) return
      var hits = msg.results || []
      // Filter out hadiths whose text and arabic are both empty — these are
      // structural entries (e.g. Imam Muslim's prose preface, Sahih Muslim #1)
      // that should never appear as search results.
      hits = hits.filter(function(r) {
        var entry = root.hadithAt(r.index)
        return entry && (entry.text || entry.arabic)
      })
      root.suggestions = (msg.query !== root.acceptedSuggestion) ? (msg.suggestions || []) : []
      root.acceptedSuggestion = ""
      root.searchPending = false
      root.pendingResults = hits
      root.truncated = hits.length >= root.maxResults
      root.revealedCount = 0
      root.selectedIndex = 0
      resultModel.clear()
      root.revealMore()
      Qt.callLater(function() { searchResultsList.positionViewAtIndex(0, ListView.Center) })
    }
  }

  // --- helpers ---------------------------------------------------------------

  function isKnownCollection(id) {
    return Model.collectionIndex(id) !== -1
  }

  function saveState() {
    var h = root.currentHadith
    if (!h) return
    hadithStateFile.setText(JSON.stringify({ collection: root.collectionId, hadithNumber: h.number }))
  }

  function loadCollection(id) {
    // Defense-in-depth: never build a FileView path from an unvalidated id.
    if (!root.isKnownCollection(id)) return
    // Already loaded: just re-center on the preserved position.
    if (root.edition && root.collectionId === id) {
      root.scrollToCurrent()
      return
    }
    root.collectionId = id
    root.edition = null
    root.hadithIndex = 0
    // The path binding triggers onLoaded when it resolves.
  }

  // Slim the normalized hadith array down to the search-relevant fields
  // (number/t/a) for the worker seed. number is the normalized long-form key;
  // t/a remain the compact short-form keys the worker reads.
  function slimForWorker(chapterHadiths) {
    var out = []
    for (var i = 0; i < chapterHadiths.length; i++) {
      var h = chapterHadiths[i]
      out.push({ number: h.number, t: h.t, a: h.a })
    }
    return out
  }

  // Normalize compact-format chapter rows to the long-form keys the delegates
  // read (name/first/last/name_ar) and reset startIndex before assignment.
  // Mutates and returns the chapters array in place.
  function _normalizeChapters(rawChapters) {
    var chs = rawChapters
    for (var ci = 0; ci < chs.length; ci++) {
      var c = chs[ci]
      if (!c.name) c.name = c.n
      if (!c.first) c.first = c.f
      if (!c.last)  c.last  = c.l
      if (!c.name_ar) c.name_ar = c.a || c.name
      c.startIndex = -1 // computed in _assignChapters
    }
    return chs
  }

  // Normalize hadith rows (n/t/a/g → number/text/arabic/grade) and assign each
  // to its chapter via a two-pointer walk, writing chapterIndex/book/book_ar
  // and each chapter's startIndex. Mutates and returns the hadiths array.
  function _assignChapters(hadiths, chapters) {
    var hs = hadiths
    var chs = chapters
    var chp = 0  // chapter pointer, advances monotonically across sorted hadiths
    for (var hi = 0; hi < hs.length; hi++) {
      var h = hs[hi]
      if (!h.number)  h.number  = h.n
      if (!h.text)    h.text    = h.t
      if (!h.arabic)  h.arabic  = h.a
      if (!h.grade)   h.grade   = h.g
      // Two-pointer O(H+C) chapter assignment. Both the hadiths (by number)
      // and the chapters (by [first,last] range) are sorted, so a single
      // chapter pointer advances monotonically across all hadiths — replacing
      // the previous O(H×C) linear scan per hadith (~730K comparisons for
      // bukhari) with ~H+C moves.
      while (chp < chs.length - 1 && h.number > chs[chp].last) chp++
      if (h.number >= chs[chp].first && h.number <= chs[chp].last) {
        h.chapterIndex = chp
        h.book = chs[chp].name
        h.book_ar = chs[chp].name_ar || chs[chp].name
        if (chs[chp].startIndex === -1) chs[chp].startIndex = hi
      } else {
        h.chapterIndex = -1
        h.book = ""
      }
    }
    // Chapters with no hadiths keep startIndex = total for zero-length range.
    for (var ci = 0; ci < chs.length; ci++) {
      if (chs[ci].startIndex === -1) chs[ci].startIndex = hs.length
    }
    return hs
  }

  function onEditionLoaded(obj) {
    if (!obj || !obj.name || !Array.isArray(obj.chapters) || !Array.isArray(obj.hadiths)) return
    // Normalize compact-format data to the long-form keys the rest of the tab
    // expects. The bundled data files use n/t/a/g (hadiths) and n/f/l
    // (chapters) to keep the files small, but the delegates and search logic
    // reference number/text/arabic/grade/name/first/last at every call site.
    var chs = _normalizeChapters(obj.chapters)
    _assignChapters(obj.hadiths, chs)
    root.edition = obj
    if (root.openAtLastHadith && root.totalHadiths > 0) {
      root.hadithIndex = root.totalHadiths - 1
    } else {
      root.positionAtNumber(root.targetNumber)
    }
    root.openAtLastHadith = false
    root.mode = root.modeAfterLoad
    root.saveState()
    // Pre-seed the search worker so the corpus builds now instead of on first
    // keystroke — removes the ~200ms first-search delay from the dropdown.
    if (root.seededCollection !== root.collectionId) {
      var workerHadiths = slimForWorker(root.edition ? root.edition.hadiths : [])
      hadithSearchWorker.sendMessage({ query: "", queryType: "text", hadiths: workerHadiths })
      root.seededCollection = root.collectionId
    }
  }

  // The active collection failed to load or parse. Bundled data should always
  // resolve, but on a missing/corrupt file leave the reader empty (rather than
  // showing the previous collection) so the failure is visible instead of stale.
  function onEditionLoadFailed() {
    root.edition = null
    root.mode = "read"
  }

  // Resolve a hadith number to a 0-based index. Numbers are monotonic, so the
  // first index whose number is >= the target is the right slot; a fractional
  // target (e.g. 402.2) lands on its exact sub-hadith.
  function indexForHadithNumber(num) {
    var hs = root.hadiths
    for (var i = 0; i < hs.length; i++) {
      if (hs[i].number >= num) return i
    }
    return hs.length > 0 ? hs.length - 1 : 0
  }

  function positionAtNumber(num) {
    if (root.totalHadiths === 0) return
    root.hadithIndex = root.indexForHadithNumber(num)
    root.scrollToCurrent()
  }

  function hadithAt(index) {
    return (root.totalHadiths > 0 && index >= 0 && index < root.totalHadiths)
      ? root.hadiths[index] : null
  }

  // Collapse a grade label to its short form for the badge/chip: drop the
  // grading source parenthetical (e.g. "Sahih (Darussalam)" → "Sahih") and cap
  // anything longer than a chip-width at 12 chars.
  function shortGrade(grade) {
    if (!grade) return ""
    var s = String(grade).trim()
    var parts = s.split("(")
    s = parts[0].trim()
    var tokens = s.split(/[:,;]\s+/)
    var seen = {}
    var unique = tokens.filter(function(t) {
      var key = t.trim()
      if (!key || seen[key]) return false
      seen[key] = true
      return true
    })
    var result = unique.join(": ")
    return I18n.translateGrade(result, root.language)
  }

  // Display-time cleanup for hadith text — the bundled data sometimes omits the
  // space after a colon (e.g. "that:The Messenger").
  function sanitizeText(s) {
    if (!s) return ""
    return s.replace(/\bthat:(?!\s)/g, "that: ")
  }

  // --- navigation ------------------------------------------------------------

  function stepHadith(delta) {
    if (root.totalHadiths === 0) return
    var next = root.hadithIndex + delta

    // Cross-collection navigation: wrap to next/prev collection at boundaries.
    if (next >= root.totalHadiths) {
      root.stepCollection(1)
      return
    }
    if (next < 0) {
      root.stepCollection(-1)
      return
    }
    root.hadithIndex = next
    root.scrollToCurrent()
    root.saveState()
  }

  function stepChapter(delta) {
    if (root.chapters.length === 0) return
    var idx = root.currentChapterIndex

    // In chapters mode the user is browsing the chapter list — start from the
    // first chapter (delta > 0) or last chapter (delta < 0) instead of the
    // old hadith's chapter, so "next" consistently opens chapter 1.
    if (root.mode === "chapters") {
      if (delta > 0) {
        root.goToChapter(0)
      } else if (delta < 0) {
        root.goToChapter(root.chapters.length - 1)
      }
      return
    }
    // A prefatory note (book 0) has no chapter; resolve the surrounding one
    if (idx < 0) {
      for (var i = 0; i < root.chapters.length; i++) {
        if (root.chapters[i].startIndex <= root.hadithIndex) idx = i
      }
    }
    if (idx < 0) return
    var target = idx + delta

    // Cross-collection: step past the last/first chapter wraps to next/prev collection.
    if (target >= root.chapters.length) {
      root.stepCollection(1)
      return
    }
    if (target < 0) {
      root.stepCollection(-1)
      return
    }
    root.goToChapter(target)
  }

  // Switch to the next (delta = 1) or previous (delta = -1) collection. Lands
  // on the first hadith of the first chapter or the last hadith of the last
  // chapter so Left/Right from either end stays natural.
  function stepCollection(delta) {
    var ci = root.collectionIndex
    if (ci < 0) return
    var next = ci + delta
    if (next < 0 || next >= root.collections.length) return
    var id = root.collections[next].id
    // Go backwards: land on the last hadith so Right steps into the first chapter.
    root.openAtLastHadith = delta < 0
    root.switchCollection(id)
  }

  function goToChapter(index) {
    if (!root.edition || index < 0 || index >= root.chapters.length) return
    root.mode = "read"
    root.hadithIndex = root.chapters[index].startIndex
    root.scrollToCurrent()
    root.saveState()
  }

  // Jump to a 1-based position within the current chapter (from the position bar).
  function jumpToHadith(position) {
    if (root.totalHadiths === 0 || root.currentChapterIndex < 0) return
    var clamped = Math.max(1, Math.min(root.currentChapterEnd - root.currentChapterStart + 1, position))
    root.hadithIndex = root.currentChapterStart + clamped - 1
    root.scrollToCurrent()
    root.saveState()
  }

  function scrollToCurrent() {
    if (root.totalHadiths === 0) return
    // Silently ignore: view may not be laid out during an in-flight collection load.
    try { hadithList.positionViewAtIndex(root.hadithIndex, ListView.Center)
    } catch (e) { /* no-op: view not laid out yet */ }
  }

  function switchCollection(id) {
    if (id === root.collectionId && root.edition) {
      root.mode = "chapters"
      return
    }
    // Cross-collection navigation preserves openAtLastHadith from stepCollection();
    // manual pick via the collections list resets to chapter 1.
    root.targetNumber = 1
    root.modeAfterLoad = root.openAtLastHadith ? "read" : "chapters"
    root.clearSearch()
    root.keyCatcher.forceActiveFocus()
    root.loadCollection(id)
  }

  // --- activate / search -----------------------------------------------------

  // Enter/Space from the panel key catcher: open the selected search result,
  // or copy the current hadith in read mode.
  function activate() {
    if (root.searchActive) {
      if (resultModel.count > 0) root.openResult(root.selectedIndex)
      else root.clearSearch()
      return
    }
    var h = root.currentHadith
    if (h) root.copyHadith(h)
  }

  // shared logic — keep in sync with QuranTab.applySuggestion
  function applySuggestion(sug) {
    root.suggestions = []
    // "{label} N" suggestions carry the bare number for numeric search.
    var labelPrefix = __("hadith.label")
    var isHadithNum = sug.indexOf(labelPrefix) === 0 && /^\d+$/.test(sug.slice(labelPrefix.length))
    var text = isHadithNum ? sug.slice(labelPrefix.length) : sug
    root.acceptedSuggestion = text
    root.query = text
    searchField.text = text
    searchTimer.stop()   // suppress the onTextChanged → timer re-trigger
    searchField.forceActiveFocus()
    root.performSearch()
  }

  // Reset transient search state — shared by clearSearch and performSearch.
  // shared logic — keep in sync with QuranTab.resetSearchState: Quran also clears
  // statusText (Hadith derives searchStatus instead).
  function resetSearchState() {
    resultModel.clear()
    root.pendingResults = []
    root.revealedCount = 0
    root.truncated = false
    SearchFlight.clear(root.flight)
  }

  function clearSearch() {
    root.query = ""
    // Set the field text directly (not just query): typing breaks the text
    // binding, so the field would keep stale text otherwise.
    searchField.text = ""
    root.suggestions = []
    root.selectedIndex = 0
    root.searchPending = false
    root.searchActive = false
    root.resetSearchState()
  }

  // Append the next pageSize pending results into resultModel (Bible pattern).
  // shared logic — keep in sync with QuranTab.revealMore: only the appended row
  // schema differs (hadithIdx here vs surahId/ayahN/ar/en there).
  function revealMore() {
    var end = Math.min(root.pendingResults.length, root.revealedCount + root.pageSize)
    for (var i = root.revealedCount; i < end; i++) {
      resultModel.append({ hadithIdx: root.pendingResults[i].index })
    }
    root.revealedCount = end
  }

  function performSearch() {
    var q = String(root.query).replace(/^\s+|\s+$/g, "")
    root.suggestions = []
    root.selectedIndex = 0
    root.resetSearchState()
    if (q === "" || root.totalHadiths === 0) {
      root.searchPending = false
      root.searchActive = false
      return
    }
    root.searchActive = true
    root.searchPending = true
    // Single-flight: queue the query and dispatch only when nothing is in
    // flight (see flushSearchPending).
    if (SearchFlight.enqueue(root.flight, root.query)) root.flushSearchPending()
  }

  function flushSearchPending() {
    var query = SearchFlight.takePending(root.flight)
    if (query === "") return
    // A bare number shows the matching hadith as a search result (like Bible:
    // the user must press Enter to open it — no auto-jump). The whole search
    // runs off the UI thread in HadithSearchWorker.js; the normalized hadith
    // array is re-sent only when the collection changes.
    var numeric = /^\d+$/.test(query) && parseInt(query, 10) >= 1
    var msg = { query: query, queryType: numeric ? "numeric" : "text" }
    // Pass the localized "Hadith " label so the worker's number-prefix
    // suggestions ("Hadith N") match the active language.
    msg.hadithLabelPrefix = I18n.get("hadith.label", root.language)
    if (root.seededCollection !== root.collectionId) {
      // Send only search-relevant fields; the worker computes textLower /
      // enTok / arabicStripped once when seeding.
      msg.hadiths = slimForWorker(root.edition ? root.edition.hadiths : [])
      root.seededCollection = root.collectionId
    }
    hadithSearchWorker.sendMessage(msg)
    SearchFlight.markSent(root.flight)
  }

  // shared logic — keep in sync with QuranTab.moveSelection: only the result
  // ListView id differs (searchResultsList vs resultList).
  function moveSelection(delta) {
    if (resultModel.count === 0) return
    root.selectedIndex = Math.max(0, Math.min(resultModel.count - 1, root.selectedIndex + delta))
    // Reveal next page when keyboard-navigating near the end.
    if (root.selectedIndex >= resultModel.count - 3 && resultModel.count < root.pendingResults.length)
      root.revealMore()
    if (searchResultsList.visible) searchResultsList.positionViewAtIndex(root.selectedIndex, ListView.Center)
  }

  function openResult(i) {
    if (i < 0 || i >= resultModel.count) return
    var row = resultModel.get(i)
    var h = root.hadithAt(row.hadithIdx)
    if (!h) return
    root.hadithIndex = row.hadithIdx
    // Keep the query in the field (like QuranTab.openSurahAyah) so refocusing
    // re-opens suggestions; only the results/suggestions are cleared.
    root.searchActive = false
    root.suggestions = []
    root.resetSearchState()
    root.mode = "read"
    root.scrollToCurrent()
    root.saveState()
    root.keyCatcher.forceActiveFocus()
  }

  function copyHadith(h) {
    if (!h) return
    var ref = root.collectionName + " " + h.number
    var footer = ref
    if (h.grade) footer += " — " + I18n.translateGrade(h.grade, root.language)
    copyHelper.copy(h.arabic, h.text, root.language, ref, footer + "\n\n" + __("copy.footer"))
  }

  // --- layout ----------------------------------------------------------------

  // === Content area ===
  Column {
    width: parent.width
    spacing: Style.spacing.sm

    // Search field — always visible, not hidden behind a toggle.
    QuranSearchField {
      id: searchField
      width: parent.width
      placeholderText: _("search.hadith", {collection: root.collectionName})
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
      // shared logic — keep in sync with QuranTab's searchField wiring:
      // onTextChanged / onActiveFocusChanged / onNavigate differ only in the query
      // property name (query vs searchText); Hadith adds onAccepted for Enter.
      onTextChanged: {
        root.query = text
        if (text !== "") searchTimer.restart()
        else root.clearSearch()
      }
      onActiveFocusChanged: {
        if (activeFocus && text !== "") searchTimer.restart()
      }
      onNavigate: function(delta) { root.moveSelection(delta) }
      // onAccepted replaces QuranSearchField's internal onAccepted; explicitly
      // restore focus here.
      onAccepted: {
        if (resultModel.count > 0) root.openResult(root.selectedIndex)
        else root.keyCatcher.forceActiveFocus()
      }
    }

    // Autocomplete suggestions — shown while the field has focus.
    SuggestionList {
      width: parent.width
      visible: searchField.activeFocus && root.suggestions.length > 0
      suggestions: root.suggestions
      surfaceColor: root.surfaceColor; hoverTint: root.hoverTint
      borderColor: root.borderColor; contentForeground: root.contentForeground; fontFamily: root.fontFamily
      onApplySuggestion: function(text) { root.applySuggestion(text) }
    }

    // Search status line (result count or "No results").
    QuranStatusRow {
      visible: root.searchActive
      label: root.searchStatus
      showHint: resultModel.count > 0
      language: root.language
      contentForeground: root.contentForeground
      mutedForeground: root.mutedForeground
      dimOpacity: root.dimOpacity
      fontFamily: root.fontFamily
    }

    // Search results (replace the reader while searching).
    ListView {
      id: searchResultsList
      width: parent.width
      height: Math.min(Style.space(320), Math.max(Style.space(96), contentHeight))
      visible: resultModel.count > 0
      model: resultModel
      spacing: Style.spacing.xs
      clip: true
      boundsBehavior: Flickable.StopAtBounds

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

        // Resolve the hadith behind this result row via the ListModel role.
        readonly property var currentHadith: root.hadithAt(hadithIdx)
        readonly property string resultBook: currentHadith
          ? Model.localizedName(currentHadith.book || "", currentHadith.book_ar, root.language) : ""

        QuranResultCard {
          id: resultCard
          width: parent.width
          rowIndex: index
          itemCount: resultModel.count
          selected: root.selectedIndex === index
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

          title: currentHadith ? _("hadith.result", {book: resultBook, number: String(currentHadith.number)}) : ""
          grade: currentHadith ? root.shortGrade(currentHadith.grade) : ""
          english: currentHadith ? Search.highlightQuery(
              root.sanitizeText(currentHadith.text.length > 160 ? currentHadith.text.substring(0, 160) + "\u2026" : currentHadith.text),
              root.query, root.accentColor) : ""
          englishRich: true

          onEntered: function(i) { root.selectedIndex = i }
          onClicked: root.openResult(index)
        }
      }
    }

    // ---- read / chapters / collections content ------------------------------
    Column {
      width: parent.width
      visible: !root.searchActive
      spacing: Style.spacing.sm
      topPadding: Style.spacing.lg

      QuranReaderHeader {
        title: root.headerTitle
        subtitle: root.headerSubtitle
        positionValue: root.currentChapterLength > 0 ? root.positionInChapter : 0
        positionMax: root.currentChapterLength
        positionLabelPrefix: __("hadith.label")
        positionOffset: {
          var ci = root.currentChapterIndex
          return ci >= 0 ? root.chapters[ci].startIndex : 0
        }
        positionTotalMax: root.totalHadiths
        positionChapterLabel: __("hadith.chapter")
        positionTotalLabel: __("hadith.total")
        showExtraButton: true
        extraButtonActive: root.mode !== "read"
        accentColor: root.accentColor
        hoverTint: root.hoverTint
        selectionTint: root.selectionTint
        contentForeground: root.contentForeground
        surfaceColor: root.surfaceColor
        fontFamily: root.fontFamily
        dimOpacity: root.dimOpacity
        keyCatcher: root.keyCatcher
        onJump: function (target) { root.jumpToHadith(target) }
        onPrev: root.stepChapter(-1)
        onNext: root.stepChapter(1)
        onExtraClicked: {
          // ☰ toggles between reading (read/chapters) and the collection picker.
          if (root.mode === "collections") root.mode = "read"
          else root.mode = "collections"
        }
      }

      QuranCopyFeedback {
        copyFeedback: copyHelper.feedback
        fontFamily: root.fontFamily
        accentColor: root.accentColor
      }

      // Guaranteed breathing room between the header and the scroll content,
      // independent of whether copy feedback is showing.
      Item { width: parent.width; height: Style.space(16) }

      // -- Read-mode hadith list.
      ListView {
        id: hadithList
        width: parent.width
        height: Math.min(root.readerHeight, hadithList.contentHeight)
        visible: root.mode === "read" && root.totalHadiths > 0
        clip: true
        model: root.hadiths
        spacing: Style.spacing.lg
        boundsBehavior: Flickable.StopAtBounds
        footer: Item { width: parent.width; height: Style.spacing.lg }
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        delegate: Item {
          required property var modelData
          required property int index
          readonly property bool selected: index === root.hadithIndex
          readonly property string _gradeLabel: root.shortGrade(modelData.grade)
          width: hadithList.width
          height: entryColumn.implicitHeight

          // Selection background (same as QuranTab's verse delegate).
          Rectangle {
            anchors.fill: parent
            color: selected ? root.selectionTint : "transparent"
            radius: Style.space(3)
          }

          Column {
            id: entryColumn
            width: parent.width
            spacing: Style.space(4)

            Text {
              width: parent.width
              text: root.collectionName + " \u00b7 " + Model.localizedName(modelData.book || "", modelData.book_ar, root.language)
              textFormat: Text.PlainText
              color: selected ? root.contentForeground : root.mutedForeground
              opacity: 0.75
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: __("hadith.label") + modelData.number
              textFormat: Text.PlainText
              color: index === root.hadithIndex ? root.accentColor : root.contentForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              width: parent.width
              visible: root.language !== "english"
              text: modelData.arabic
              // Some collections (e.g. Forty Hadith Qudsi) embed "<br>" line
              // breaks in the Arabic source. StyledText interprets those tags
              // (and is a safe HTML subset) instead of showing them literally.
              textFormat: Text.StyledText
              color: index === root.hadithIndex ? root.accentColor : root.contentForeground
              font.family: root.arabicFontFamily
              font.pixelSize: Style.font.subtitle
              horizontalAlignment: Text.AlignRight
              wrapMode: Text.WordWrap
              leftPadding: Style.space(4)
              rightPadding: Style.space(4)
              lineHeight: 2.0
            }

            // Subtle gold separator between Arabic hadith body and English
            // translation — gives each script its own breathing room.
            Rectangle {
              width: parent.width * 0.4
              height: Style.space(1)
              color: root.accentColor
              opacity: 0.25
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
              width: parent.width
              visible: root.language !== "arabic"
              text: root.sanitizeText(modelData.text)
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.readerFontFamily
              font.pixelSize: Style.font.heading
              wrapMode: Text.WordWrap
              lineHeight: 1.5
            }

            Text {
              width: parent.width
              visible: _gradeLabel !== ""
              text: _("grade.bracket", {grade: _gradeLabel})
              textFormat: Text.PlainText
              color: root.contentForeground
              opacity: 0.65
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.keyCatcher.forceActiveFocus()
              root.hadithIndex = index
              root.scrollToCurrent()
              root.copyHadith(root.hadithAt(index))
            }
          }
        }

        onContentYChanged: {
          var center = contentY + height / 2
          var idx = indexAt(0, center)
          if (idx >= 0) root.hadithIndex = idx
        }
      }

      // -- Chapters mode.
      ListView {
        id: chapterPicker
        width: parent.width
        height: Math.min(root.readerHeight, chapterPicker.contentHeight)
        visible: root.mode === "chapters"
        clip: true
        model: root.chapters
        spacing: Style.spacing.xs
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        delegate: Item {
          required property var modelData
          required property int index
          width: chapterPicker.width
          height: chapterText.implicitHeight + Style.space(4)

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: chapterMouse.containsMouse ? root.hoverTint : root.surfaceColor
            border.width: Style.space(1)
            border.color: root.borderColor
          }

          Text {
            id: chapterText
            width: parent.width
            text: Model.localizedName(modelData.name, modelData.name_ar, root.language) + " \u00b7 " + modelData.first + "\u2013" + modelData.last
            textFormat: Text.PlainText
            color: index === root.currentChapterIndex ? root.accentColor : root.contentForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: index === root.currentChapterIndex
            wrapMode: Text.WordWrap
          }

          MouseArea {
            id: chapterMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.keyCatcher.forceActiveFocus()
              root.goToChapter(index)
            }
          }
        }
      }

      // -- Collections mode.
      ListView {
        id: collectionPicker
        width: parent.width
        height: Math.min(root.readerHeight, collectionPicker.contentHeight)
        visible: root.mode === "collections"
        clip: true
        model: root.collections
        spacing: Style.spacing.xs
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        delegate: Item {
          required property var modelData
          width: collectionPicker.width
          height: Style.space(32)

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: pickerMouse.containsMouse ? root.hoverTint : root.surfaceColor
            border.width: Style.space(1)
            border.color: root.borderColor
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Model.localizedName(modelData.name, modelData.name_ar, root.language)
            textFormat: Text.PlainText
            color: modelData.id === root.collectionId ? root.accentColor : root.contentForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: modelData.id === root.collectionId
            elide: Text.ElideRight
          }

          MouseArea {
            id: pickerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.keyCatcher.forceActiveFocus()
              root.openAtLastHadith = false
              root.switchCollection(modelData.id)
            }
          }
        }
      }
    }
  }
}
