// components/HadithSearchWorker.js — runs hadith text/number search off the UI
// thread. The normalized hadith array is cached in this worker's global scope
// and re-seeded whenever the collection changes, so subsequent searches for the
// same collection only send the query. All matching + scoring lives in search.js
// (shared with the Quran search); this worker is a thin shim over searchHadiths().

// WorkerScripts run in a separate JS context and cannot use QML imports or the
// `.import` directive. Qt.include() copies the included files' top-level
// functions into this script's namespace, so it can call searchHadiths()
// directly. Quran.js is included first so search.js's _normalizeArabic resolves
// Quran.js's foldArabic global (search.js has no inline fallback).
Qt.include("../Quran.js")
Qt.include("../search.js")

var hadiths = []
var corpus = { words: [], freq: {} }

WorkerScript.onMessage = function(msg) {
  try {
    if (msg.hadiths) {
      // The UI thread sends a slim payload with only number/t/a. Compute
      // textLower/arabicStripped here in the worker so the UI thread never
      // blocks on per-hadith string normalization (saves ~200ms on first
      // collection load for bukhari ~7.5k hadiths).
      var raw = msg.hadiths
      var norm = []
      for (var i = 0; i < raw.length; i++) {
        var tLower = String(raw[i].t || "").toLowerCase()
        norm.push({
          number: raw[i].number,
          textLower: tLower,
          enTok: _tokenizeEnglish(tLower),          // pre-stripped — _matchesText bypasses re-tokenization
          arabicStripped: _normalizeArabic(String(raw[i].a || ""))
        })
      }
      hadiths = norm
      corpus = buildHadithCorpus(hadiths)
    }
    var results = searchHadiths(hadiths, msg.query, msg.queryType)

    var suggestions = []
    var queryLower = String(msg.query || "").toLowerCase().trim()
    if (corpus.words.length > 0 && queryLower.length >= 1) suggestions = prefixMatches(corpus, queryLower, 8)
    // Number-prefix suggestions: when the query is all digits (e.g. "1", "10"),
    // generate "Hadith N" entries for hadiths whose number starts with that prefix
    // so the user can jump directly to a specific hadith.
    if (/^\d+$/.test(msg.query || "") && hadiths.length > 0 && suggestions.length < 10) {
      var prefix = msg.query.trim()
      var count = 0
      for (var n = 0; n < hadiths.length && count < 10 - suggestions.length; n++) {
        if (String(hadiths[n].number).indexOf(prefix) === 0) {
          suggestions.push(msg.hadithLabelPrefix + hadiths[n].number)
          count++
        }
      }
    }
    if (suggestions.length > 10) suggestions = suggestions.slice(0, 10)

    WorkerScript.sendMessage({
      results: results,
      suggestions: suggestions,
      query: msg.query
    })
  } catch (e) {
    WorkerScript.sendMessage({
      results: [],
      suggestions: [],
      query: msg.query
    })
  }
}
