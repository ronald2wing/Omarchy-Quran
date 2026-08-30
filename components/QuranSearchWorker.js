// QuranSearchWorker.js — runs Quran text search off the UI thread.
// The parsed quran.json data is cached in this worker's global scope after the
// first message that carries it, so subsequent searches only send the query.
// IDF weights (buildIdf) and the suggestion corpus (buildCorpus) are both
// computed once when the data first arrives, so scoring and suggestions never
// re-tokenize the ~6k ayah strings per query.

// WorkerScripts run in a separate JS context and cannot use QML `import` or the
// `.import` directive. Qt.include() copies another script's top-level functions
// into this script's namespace — Quran.js first so search.js's `Quran.parseReference`
// calls resolve, then search.js (shared with the QML panel and the node tests).
Qt.include("../Quran.js")
Qt.include("../search.js")

var idf = null

var data = null
var corpus = { words: [], freq: {} }

WorkerScript.onMessage = function(msg) {
  try {
    if (msg.data) {
      data = msg.data
      idf = buildIdf(data)
      corpus = buildCorpus(data)
    }
    // Clamp the query so a huge pasted string can't fan out into unbounded
    // work. The unclamped msg.query is echoed back so the panel's stale-response
    // guard (msg.query !== root.query) still matches.
    // msg.textQuery (optional) overrides the text to search — used when the
    // panel already resolved a reference ("2:255"), so the worker searches for
    // the *remaining* text words instead of the bare reference.
    var q = String(msg.textQuery || msg.query || "").slice(0, 500)

    // The panel may pass a surah-specific result cap for bare-reference queries.
    var cap = typeof msg.maxResults === "number" && msg.maxResults > 0 ? msg.maxResults : undefined
    // proximityRef is set for full reference queries (e.g. "2:2") so results
    // show the target ayah first, then neighbors by distance.
    var proximity = msg.proximityRef || null

    var results = searchAyahs(data, q, cap, idf, proximity)

    // Word-prefix + reference suggestions, computed off the cached corpus so the
    // UI thread never re-tokenizes the text. Reference suggestions are prepended
    // (they are exact targets); word suggestions follow. Capped at 10.
    var queryLower = msg.query.toLowerCase().trim()
    var suggestions = []
    if (corpus.words.length > 0 && queryLower.length >= 1) suggestions = prefixMatches(corpus, queryLower, 8)
    var refSuggestions = data ? suggestReferences(data, msg.query, 5) : []
    // Reference suggestions come first (exact match at position 0), followed by
    // word-prefix completions. Dedupe: drop any word completion already present
    // in the reference suggestions, then cap the combined list at 10.
    var seen = {}
    for (var i = 0; i < refSuggestions.length; i++) seen[refSuggestions[i]] = true
    var uniqueWords = []
    for (var j = 0; j < suggestions.length; j++) {
      if (!seen[suggestions[j]]) uniqueWords.push(suggestions[j])
    }
    suggestions = refSuggestions.concat(uniqueWords)
    if (suggestions.length > 10) suggestions = suggestions.slice(0, 10)

    WorkerScript.sendMessage({ results: results, suggestions: suggestions, query: msg.query, searchGeneration: msg.searchGeneration })
  } catch (e) {
    // Always reply so the panel's in-flight count bookkeeping (which expects
    // exactly one reply per dispatch) can never wedge.
    WorkerScript.sendMessage({ results: [], suggestions: [], query: msg.query, searchGeneration: msg.searchGeneration })
  }
}
