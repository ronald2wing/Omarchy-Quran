// search.js — Shared search engine for Quran text, references, and hadith.
// Platform-free: loaded via `import "../search.js" as Search` in QML,
// `Qt.include("search.js")` in the search workers, and `require("../search.js")`
// in Node tests. Text search is a case-insensitive substring match over the
// lowercased + Arabic-normalized text of each field, ranked by match position;
// reference search delegates to Quran.parseReference; hadith search reuses the
// same matcher/scorer via searchHadiths().
//
// Like Model.js, the `Quran` namespace is deliberately not declared with `var`
// here: in QML it resolves to the importing document's `import "Quran.js" as
// Quran`, and under Node the bare assignment below creates a global the QML
// engine never sees.
if (typeof module !== "undefined" && module.exports) {
  Quran = require("./Quran.js")
}

var DEFAULT_MAX_RESULTS = 114  // shared result cap (114 surahs; hadith text results too)

// Concept expansion map — hand-curated English query terms mapped to related
// concepts. When a user searches for a key word, its expansions also match
// (at 0.5x IDF weight) so conceptual queries surface relevant verses even
// without literal word matches.
// This is source code (not a build artifact) because the relationships are
// semantic knowledge, not derivable from data.
var conceptMap = {
  ruler: ["govern", "judge", "authority", "king", "command", "law", "justice", "sovereign"],
  judge: ["ruler", "govern", "authority", "justice", "law", "decree", "arbitrate"],
  prayer: ["worship", "prostrate", "bow", "supplication", "invocation", "salat"],
  fast: ["abstain", "ramadan", "sawm", "refrain", "self-restraint"],
  charity: ["alms", "zakat", "give", "spend", "generosity", "donate"],
  mercy: ["compassion", "forgive", "gracious", "benevolent", "pardon"],
  heaven: ["paradise", "garden", "jannah", "bliss", "eternal"],
  hell: ["fire", "punishment", "torment", "jahannam", "blaze"],
  knowledge: ["wisdom", "learn", "understand", "intellect", "reflect", "reason"],
  patience: ["steadfast", "persevere", "endure", "forbear"],
  light: ["guidance", "illuminate", "radiant", "nur"],
  heart: ["soul", "spirit", "chest", "breast", "mind"],
  faith: ["belief", "iman", "trust", "certainty", "conviction"],
  sin: ["transgression", "wrong", "evil", "disobey", "iniquity"],
  repent: ["turn", "return", "forgive", "penitent", "tawbah"],
  war: ["fight", "battle", "strive", "struggle", "jihad", "combat"],
  peace: ["tranquility", "harmony", "salam", "security", "serenity"],
  family: ["parent", "child", "spouse", "relative", "marriage", "inherit"],
  women: ["woman", "wife", "mother", "daughter", "sister", "female"],
  wealth: ["money", "property", "possession", "treasure", "gold", "silver"],
  death: ["die", "soul", "depart", "grave", "resurrection", "hereafter"],
  day: ["hour", "judgment", "reckoning", "resurrection", "qiyamah"],
  creation: ["create", "heavens", "earth", "universe", "made", "originate"],
  truth: ["true", "reality", "certain", "right", "haqq"],
  prophet: ["messenger", "apostle", "rasul", "nabi"],
  book: ["scripture", "revelation", "torah", "gospel", "psalms", "quran"],
  covenant: ["promise", "pledge", "contract", "oath", "agreement"],
  enemy: ["foe", "adversary", "opponent", "satan", "devil"],
  morning: ["dawn", "daybreak", "sunrise", "fajr"],
  night: ["darkness", "evening", "isha", "nocturnal"],
  water: ["rain", "river", "sea", "ocean", "spring", "stream"],
  earth: ["land", "ground", "soil", "world", "terrestrial"],
  people: ["mankind", "humanity", "nations", "tribes", "community"]
}

// lowercase + trim, shared by the search entry points.
function _normalizeQuery(text) {
  return String(text || "").toLowerCase().trim()
}

// Shared tokenizer for English text: lowercases + strips non-letter ASCII so
// the corpus and the matcher stay symmetric. "Allah's" → "allahs" in both
// the index and the query, preventing the zero-results asymmetry where the
// dropdown suggests "allahs" but the matcher tests it against "allah's messenger".
// Arabic is handled separately by _normalizeArabic — never strip [^a-z] there.
function _tokenizeEnglish(text) {
  return String(text || "").toLowerCase().replace(/[^a-z\s]/g, "")
}

// Split a normalized query into match tokens, classifying each as English or
// Arabic by character range. English tokens are punctuation-stripped so they
// stay symmetric with enTok (built via _tokenizeEnglish); Arabic tokens pass
// through untouched for arabicLower matching. Tokens that strip to nothing are
// dropped so they cannot match every entry (indexOf("") === 0).
function _tokenizeQuery(q) {
  var raw = String(q || "").split(/\s+/)
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var t = raw[i]
    if (t === "") continue
    if (/[\u0600-\u06FF]/.test(t)) {
      out.push(t)
    } else {
      var stripped = t.replace(/[^a-z\s]/g, "")
      if (stripped !== "") out.push(stripped)
    }
  }
  return out
}

// Arabic normalization: single implementation lives in Quran.js:foldArabic. In
// QML this resolves through the importing document's `import "Quran.js" as
// Quran`; in Node via require("./Quran.js").foldArabic; in WorkerScript
// (Qt.include) Quran.js's foldArabic is a global. There is no inline fallback —
// every loader path provides one of these two bindings, so a local regex copy
// would be unreachable dead code.
var _foldArabic = (typeof Quran !== "undefined" && Quran.foldArabic) ? Quran.foldArabic
    : (typeof foldArabic === "function" ? foldArabic : null)

function _normalizeArabic(text) {
  return _foldArabic ? _foldArabic(text) : String(text || "")
}

// Every query word must appear as a substring in the pre-tokenized English text
// (enTok, computed once in the worker) OR the Arabic lowered (and normalized)
// text. Partial words match too, so "lo" finds "love" and "lord". A query that
// folds to nothing (e.g. a lone hamza) matches nothing rather than everything.
// queryTokens is pre-tokenized by the caller so the per-hadith loop never
// re-normalizes the query.
function _matchesText(enTok, arabicLower, queryTokens) {
  if (queryTokens.length === 0) return false
  for (var i = 0; i < queryTokens.length; i++) {
    if (enTok.indexOf(queryTokens[i]) === -1 && arabicLower.indexOf(queryTokens[i]) === -1) return false
  }
  return true
}

// Memoized per-ayah search index
// Arabic-normalized text are computed once per data object (keyed by object
// identity) so searchAyahs never re-processes the ~6k ayah strings on each
// query. A single-slot cache keeps the index off the data object (so it is
// not serialized to the worker) while staying ES5-safe: the QML worker engine
// that loads this file via Qt.include lacks ES6 Map. The worker holds one data
// object at a time, so one slot is enough.
var _ayahIndexCache = null
var _ayahIndexCacheKey = null

function _index(data) {
  if (!data || !data.surahs) return []
  if (_ayahIndexCacheKey === data) return _ayahIndexCache
  var entries = []
  for (var i = 0; i < data.surahs.length; i++) {
    var s = data.surahs[i]
    for (var j = 0; j < s.ayahs.length; j++) {
      var a = s.ayahs[j]
      entries.push({
        surahId: s.id,
        ayahN: a.n,
        ar: a.ar || "",
        en: a.en || "",
        enTok: _tokenizeEnglish(a.en || ""),
        arabicLower: _normalizeArabic(a.ar || "").toLowerCase(),
        ref: String(s.id) + ":" + a.n
      })
    }
  }
  _ayahIndexCacheKey = data
  _ayahIndexCache = entries
  return entries
}

// Build a map of "surahId:ayahN" → proximity score for every ayah in the
// reference surah, so text-relevance scoring can merge the proximity
// dimension below. Returns null when no valid reference target is given.
function _buildProximityMap(entries, proximityRef) {
  if (!proximityRef || !proximityRef.surahId || !(proximityRef.ayahN > 0)) return null
  var map = {}
  for (var pi = 0; pi < entries.length; pi++) {
    if (entries[pi].surahId !== proximityRef.surahId) continue
    var dist = Math.abs(entries[pi].ayahN - proximityRef.ayahN)
    map[String(entries[pi].surahId) + ":" + entries[pi].ayahN] = 4 / (1 + dist)
  }
  return map
}

// When proximity search yields too few results, collect the neighboring ayat
// that had no text match so a bare reference like "2:2" still lists them by
// distance. Mutates `scored` in place.
function _collectProximityFallback(entries, proxMap, scored) {
  for (var key in proxMap) {
    if (!proxMap.hasOwnProperty(key)) continue
    var parts = key.split(":")
    var parsedSurahId = parseInt(parts[0], 10)
    var parsedAyahN = parseInt(parts[1], 10)
    // Look up from index
    for (var foundIndex = 0; foundIndex < entries.length; foundIndex++) {
      if (entries[foundIndex].surahId === parsedSurahId && entries[foundIndex].ayahN === parsedAyahN) {
        scored.push({
          surahId: parsedSurahId,
          ayahN: parsedAyahN,
          ar: entries[foundIndex].ar,
          en: entries[foundIndex].en,
          score: proxMap[key]
        })
        break
      }
    }
  }
}

// Text search over all ayahs with IDF-weighted relevance scoring.
//
// Scoring per verse (summed over all matched query terms):
//
//   score = sum( idf[term] × posDecay ) × coverage × phraseBoost
//
// idf[term]     — inverse document frequency: rare words ("throne") dominate
//                  common words ("allah"). Computed at runtime via buildIdf().
// posDecay      — 1.0 - (firstMatchPos / verseLen); earlier matches rank higher.
// coverage      — tokensMatched / queryTokens; queries where every word matches
//                  rank above partial matches. Also penalizes extra noise tokens.
// phraseBoost   — ×2.0 when all query tokens appear as a contiguous subsequence
//                  in the verse (exact phrase match).
//
// When proximityRef is provided (e.g. {surahId: 2, ayahN: 2}), results come
// from that surah ranked by distance from the target ayah:
//
//   score = 4.0 / (1.0 + |ayahN - targetN|)
//
// The exact ayah gets max score (4.0), adjacents get 2.0, etc.
function searchAyahs(data, query, maxResults, idf, proximityRef) {
  var max = typeof maxResults === "number" && maxResults > 0 ? maxResults : DEFAULT_MAX_RESULTS
  var q = _normalizeQuery(query).slice(0, 500)
  if (q === "" || !data || !data.surahs) return []
  var entries = _index(data)
  var scored = []

  // Build a proximity-score map when a reference target is provided so
  // text-relevance scoring can merge both dimensions below.
  var proxMap = _buildProximityMap(entries, proximityRef)

  // --- text relevance scoring -------------------------------------------
  idf = idf || {}

  var queryTokens = _tokenizeQuery(q)

  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i]
    var refHit = entry.ref && entry.ref === q  // exact ref match only — prefix matching ("2:2" in "2:20") causes false positives

    var verseText = entry.enTok
    var arText = entry.arabicLower

    // Score by matching query tokens (exact or expanded) against verse text.
    // Exact tokens get full IDF weight; expanded tokens get 0.5 × IDF weight.
    var score = 0
    var matchedTokens = 0
    var allAdjacent = queryTokens.length > 1  // stays false for single-word queries
    var prevPos = -1

    for (var ti = 0; ti < queryTokens.length; ti++) {
      var token = queryTokens[ti]
      var weight = idf[token] || 1.0

      // Check if this exact token or any of its expansions match
      var matched = false
      var bestPos = verseText.length
      var pos = verseText.indexOf(token)
      if (pos !== -1) {
        matched = true
        bestPos = Math.min(bestPos, pos)
      } else {
        pos = arText.indexOf(token)
        if (pos !== -1) {
          matched = true
          bestPos = Math.min(bestPos, pos)
        } else {
          // Try concept expansions with reduced weight
          var exps = conceptMap[token]
          var expWeight = weight * 0.5
          if (exps) {
            for (var xp = 0; xp < exps.length; xp++) {
              var xpos = verseText.indexOf(exps[xp])
              if (xpos !== -1) {
                matched = true
                bestPos = Math.min(bestPos, xpos)
                weight = expWeight
                break
              }
              xpos = arText.indexOf(exps[xp])
              if (xpos !== -1) {
                matched = true
                bestPos = Math.min(bestPos, xpos)
                weight = expWeight
                break
              }
            }
          }
        }
      }

      if (matched) {
        var verseLen = Math.max(1, verseText.length || 1)
        var posDecay = 1.0 - Math.min(bestPos / verseLen, 0.9)
        score += weight * posDecay
        matchedTokens++
        // Phrase detection: all tokens appear sequentially
        if (bestPos <= prevPos) allAdjacent = false
        prevPos = bestPos
      } else {
        allAdjacent = false
      }
    }

    if (matchedTokens > 0 || refHit) {
      // Multi-word queries require ALL tokens to match (AND logic);
      // single-word queries or reference hits pass immediately.
      if (queryTokens.length > 1 && matchedTokens !== queryTokens.length && !refHit) {
        // skip — not all query terms matched this verse
      } else {
        var coverage = matchedTokens / queryTokens.length
        var phraseBoost = (allAdjacent && matchedTokens === queryTokens.length) ? 2.0 : 1.0
        var finalScore = score * Math.pow(coverage, 0.5) * phraseBoost
        if (refHit) finalScore += 5.0  // exact reference match always on top
        // Merge proximity score when the user typed a verse reference
        if (proxMap) {
          var key = String(entry.surahId) + ":" + entry.ayahN
          if (proxMap[key]) finalScore += proxMap[key]
          delete proxMap[key]  // mark as consumed
        }
        scored.push({
          surahId: entry.surahId,
          ayahN: entry.ayahN,
          ar: entry.ar,
          en: entry.en,
          score: finalScore
        })
      }
    }
  }

  // Fallback: proximity entries that had no text match still get included
  // so a bare reference like "2:2" shows all neighbors by distance.
  if (proxMap) {
    _collectProximityFallback(entries, proxMap, scored)
  }

  scored.sort(function(a, b) { return b.score - a.score })

  // Strip internal scores and cap
  var out = []
  for (var k = 0; k < scored.length && k < max; k++) {
    out.push({ surahId: scored[k].surahId, ayahN: scored[k].ayahN, ar: scored[k].ar, en: scored[k].en })
  }
  return out
}

// Reference jump: parse "2:255" / "al-baqarah 255" / "البقرة 255" / "2" via
// Quran.parseReference and return the single matching ayah, or [] when the
// input is not a valid reference.
function searchByReference(data, input) {
  var ref = Quran.parseReference(input)
  if (!ref || !data || !data.surahs) return []
  for (var i = 0; i < data.surahs.length; i++) {
    if (data.surahs[i].id !== ref.surahId) continue
    var ayahs = data.surahs[i].ayahs
    if (!Array.isArray(ayahs)) return []
    for (var j = 0; j < ayahs.length; j++) {
      if (ayahs[j].n === ref.ayahN) {
        return [{ surahId: ref.surahId, ayahN: ayahs[j].n, ar: ayahs[j].ar || "", en: ayahs[j].en || "" }]
      }
    }
  }
  return []
}

// Hadith search — the max number of results per text query. The hadith
// objects sent to the worker carry {number, t, a}; the worker computes
// textLower/arabicStripped once when seeding (HadithSearchWorker.js) so no
// per-query lowercasing or Arabic normalization happens here. queryType
// "numeric" resolves a hadith number; otherwise the query is treated as text
// and results are in canonical collection order, capped at DEFAULT_MAX_RESULTS.
function searchHadiths(hadiths, query, queryType) {
  if (!Array.isArray(hadiths) || hadiths.length === 0) return []
  if (queryType === "numeric") {
    var num = parseInt(query, 10)
    if (num < 1) return []
    for (var i = 0; i < hadiths.length; i++) {
      if (hadiths[i].number >= num) return [{ index: i }]
    }
    return [{ index: hadiths.length - 1 }]
  }
  var q = String(query || "").replace(/^\s+|\s+$/g, "")
  if (q === "") return []
  // Tokenize once outside the loop — saves ~7.5k re-normalizations per keystroke.
  var queryTokens = _tokenizeEnglish(q).split(/\s+/).filter(Boolean)
  if (queryTokens.length === 0) return []
  var out = []
  for (var j = 0; j < hadiths.length && out.length < DEFAULT_MAX_RESULTS; j++) {
    var h = hadiths[j]
    // enTok is precomputed in HadithSearchWorker; falls back to textLower for
    // test paths where the mock hadiths lack the worker's normalization.
    if (_matchesText(h.enTok || _tokenizeEnglish(h.textLower), h.arabicStripped, queryTokens)) out.push({ index: j })
  }
  return out
}

// Build a word corpus for prefix-match suggestions from ayah English text.
// Returns {words, freq}: `words` is a flat array of distinct lowercased words,
// `freq` maps each word to its occurrence count across all ayahs. Built once
// per data object so suggestions never re-tokenize the ~6k ayah strings.
function buildCorpus(data) {
  var freq = {}
  if (!data || !data.surahs) return { words: [], freq: freq }
  for (var s = 0; s < data.surahs.length; s++) {
    var ayahs = data.surahs[s].ayahs
    for (var a = 0; a < ayahs.length; a++) {
      var parts = String(ayahs[a].en).toLowerCase().split(/\s+/)
      for (var w = 0; w < parts.length; w++) {
        var word = parts[w].replace(/[^a-z]/g, "")
        if (word !== "") freq[word] = (freq[word] || 0) + 1
      }
    }
  }
  var words = Object.keys(freq)
  return { words: words, freq: freq }
}

// Compute IDF word weights from the ayah index. Called once when the worker
// first receives the data; the result is cached. IDF = log(N / (df + 1)) where
// N = total ayahs, df = number of ayahs containing the word. Reusing _index()
// guarantees the tokens match what searchAyahs matches against.
function buildIdf(data) {
  var entries = _index(data)
  var df = {}
  for (var i = 0; i < entries.length; i++) {
    var seen = {}
    var tokens = entries[i].enTok.split(/\s+/).concat(entries[i].arabicLower.split(/\s+/))
    for (var t = 0; t < tokens.length; t++) {
      var word = tokens[t]
      if (word === "" || seen[word]) continue
      seen[word] = true
      df[word] = (df[word] || 0) + 1
    }
  }
  var idf = {}
  for (var w in df) idf[w] = Math.log(entries.length / (df[w] + 1))
  return idf
}

// Build a word corpus from hadith English + Arabic text for prefix matching.
// English words are lowercased; Arabic words are normalized via
// _normalizeArabic (tashkeel stripped, variants folded, ال kept) so a query
// typed without diacritics matches voweled hadith text. Words are deduped
// across both languages and frequency-weighted.
function buildHadithCorpus(hadiths) {
  var freq = {}
  if (!Array.isArray(hadiths)) return { words: [], freq: freq }
  for (var i = 0; i < hadiths.length; i++) {
    // enTok is precomputed by HadithSearchWorker; if absent (test path), strip
    // punctuation per-word to stay symmetric with the corpus-build rules.
    var enParts
    if (hadiths[i].enTok) {
      enParts = hadiths[i].enTok.split(/\s+/)
    } else {
      enParts = String(hadiths[i].textLower || "").split(/\s+/)
      for (var ew = 0; ew < enParts.length; ew++) enParts[ew] = enParts[ew].replace(/[^a-z]/g, "")
    }
    for (var ew = 0; ew < enParts.length; ew++) {
      if (enParts[ew] !== "") freq[enParts[ew]] = (freq[enParts[ew]] || 0) + 1
    }
    // Arabic words — arabicStripped is already normalized by the worker
    var arText = String(hadiths[i].arabicStripped || "")
    var arParts = arText.split(/\s+/)
    for (var aw = 0; aw < arParts.length; aw++) {
      var arWord = arParts[aw].replace(/[^\u0600-\u06FF]/g, "")
      if (arWord !== "") freq[arWord] = (freq[arWord] || 0) + 1
    }
  }
  return { words: Object.keys(freq), freq: freq }
}

// Return up to maxResults corpus words matching the given prefix, sorted by
// log₂(frequency) so high-signal words like "prayer" rank well but common
// filler words (the → 34k) don't dominate over mid-frequency words with the
// same prefix. The log₂ squashes exponential gaps: a word appearing 2× as
// often as another gets at most +1 rank advantage, not +5000.
function prefixMatches(corpus, prefix, maxResults) {
  var out = []
  var max = typeof maxResults === "number" && maxResults > 0 ? maxResults : 8
  if (prefix === "" || !corpus) return out
  var words = corpus.words, freq = corpus.freq
  for (var i = 0; i < words.length && out.length < max * 4; i++) {
    if (words[i].indexOf(prefix) === 0) {
      // Exact match gets a +1000 boost so it always outranks partial matches,
      // even when the partial has higher corpus frequency (e.g. "allahs"
      // from "Allah's Messenger" vs "allah").
      var isExact = words[i] === prefix
      out.push({ word: words[i], score: Math.log((freq[words[i]] || 0) + 1) / Math.LN2 + (isExact ? 1000 : 0) })
    }
  }
  out.sort(function(a, b) {
    if (b.score !== a.score) return b.score - a.score
    return a.word.length - b.word.length  // tiebreak: shorter word first
  })
  return out.slice(0, max).map(function(entry) { return entry.word })
}

// Reference suggestions: surah:ayah patterns resolved via Quran.parseReference.
// In QML this goes through `import ... as Quran`; in WorkerScript (Qt.include)
// parseReference is global; for Node tests it requires Quran.js.
var resolveReference = typeof Quran !== "undefined" && Quran.parseReference ? Quran.parseReference
    : (typeof parseReference === "function" ? parseReference : null)
var formatReference = typeof Quran !== "undefined" && Quran.formatRefLocalized ? Quran.formatRefLocalized
    : (typeof formatRefLocalized === "function" ? formatRefLocalized : null)
var surahList = typeof SURAHS === "object" ? SURAHS
    : (typeof Quran !== "undefined" && Array.isArray(Quran.SURAHS) ? Quran.SURAHS : null)
var aliasMap = typeof ALIAS_EXTRAS === "object" ? ALIAS_EXTRAS
    : (typeof Quran !== "undefined" && Quran.ALIAS_EXTRAS ? Quran.ALIAS_EXTRAS : null)

function suggestReferences(data, query, maxResults) {
  var q = String(query || "").slice(0, 500).trim()
  var max = typeof maxResults === "number" && maxResults > 0 ? maxResults : 8
  if (q === "" || !data || !data.surahs) return []
  var fmt = formatReference || function(surahId, an) { return surahId + ":" + an }
  var out = []

  // Path 1 — digit:digit (or digit:) prefix completion.
  // "2:2" → 2:2, 2:20, 2:21, 2:22, 2:23, 2:24, 2:25, 2:26
  // "2:"  → 2:1, 2:2, 2:3, ...
  // This runs first so pure ref syntax always triggers prefix completion
  // rather than proximity-centered window.
  var prefixed = q.match(/^(\d+):(\d*)$/)
  if (prefixed) {
    var surahId = parseInt(prefixed[1], 10)
    if (surahId >= 1 && surahId <= 114) {
      var surah = data.surahs[surahId - 1]
      var ayahPrefix = prefixed[2] || ""
      var exact = ayahPrefix !== "" ? fmt(surahId, parseInt(ayahPrefix, 10)) : ""
      // First pass: exact match at position 0.
      if (exact !== "" && parseInt(ayahPrefix, 10) >= 1 && parseInt(ayahPrefix, 10) <= surah.ayahs.length) {
        out.push(exact)
      }
      // Second pass: ayahs whose number starts with the prefix (excluding exact).
      for (var k = 0; k < surah.ayahs.length && out.length < max; k++) {
        if (ayahPrefix === "" || String(k + 1).indexOf(ayahPrefix) === 0) {
          var label = fmt(surahId, k + 1)
          if (label !== exact) out.push(label)
        }
      }
    }
    return out.slice(0, max)
  }

  // Path 2 — named reference ("al-baqarah 255", "yasin 5"): proximity window.
  var ref = resolveReference ? resolveReference(q) : null
  if (ref && ref.surahId >= 1 && ref.surahId <= 114) {
    var surah = data.surahs[ref.surahId - 1]
    var exact = ref.ayahN ? fmt(ref.surahId, ref.ayahN) : ""
    var start = ref.ayahN ? Math.max(1, ref.ayahN - Math.floor(max / 2)) : 1
    for (var i = 0; i < max && (start + i - 1) < surah.ayahs.length; i++) {
      var label = fmt(ref.surahId, start + i)
      if (label === exact) continue
      out.push(label)
    }
    if (exact) out.unshift(exact)
    return out.slice(0, max)
  }

  // Path 3 — surah name completion, relevance-scored.
  // Collect candidates with a match-quality score, then sort and cap.
  // Scoring:  exact name match = 0, starts-with = 1, embedded = 2.
  // The alias map is also scored (alias starts-with = 1, embedded = 2).
  if (surahList && out.length < max) {
    var qLower = q.toLowerCase()
    // Gather scored candidates to sort by relevance.
    var candidates = []

    // Scan surah names (original + Al--stripped) and alias map.
    var seenNames = {}
    for (var i = 0; i < surahList.length; i++) {
      var s = surahList[i]
      var trans = (s.name_translit || "").toLowerCase()
      var stripped = trans.replace(/^al[- ]/i, "")
      var score = -1
      if (trans === qLower || stripped === qLower) score = 0
      else if (trans.indexOf(qLower) === 0 || stripped.indexOf(qLower) === 0) score = 1
      else if (trans.indexOf(qLower) > 0 || stripped.indexOf(qLower) > 0) score = 2
      if (score >= 0 && !seenNames[s.name_translit]) {
        candidates.push({ name: s.name_translit, score: score, id: s.id })
        seenNames[s.name_translit] = true
      }
    }
    if (aliasMap) {
      for (var k in aliasMap) {
        var keyLower = k.toLowerCase()
        var aliasSurahId = aliasMap[k]
        var aliasSurah = surahList[aliasSurahId - 1]
        if (!aliasSurah || seenNames[aliasSurah.name_translit]) continue
        var aliasScore = -1
        if (keyLower === qLower) aliasScore = 0
        else if (keyLower.indexOf(qLower) === 0) aliasScore = 1
        else if (keyLower.indexOf(qLower) > 0) aliasScore = 2
        if (aliasScore >= 0) {
          candidates.push({ name: aliasSurah.name_translit, score: aliasScore, id: aliasSurahId })
          seenNames[aliasSurah.name_translit] = true
        }
      }
    }
    candidates.sort(function(a, b) {
      if (a.score !== b.score) return a.score - b.score
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
    })
    for (var ci = 0; ci < candidates.length && out.length < max; ci++) {
      out.push(candidates[ci].name)
    }
  }
  return out
}

function _escapeRegex(str) { return String(str).replace(/[.*+?^${}()|[\]\\]/g, "\\$&") }
function _escapeHtml(str) {
  return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Wrap occurrences of query words in the given text with an accent-colored tag.
// Returns SafeHtml suitable for Text { textFormat: Text.RichText }.
function highlightQuery(text, query, accentColor) {
  var t = String(text || "")
  var q = String(query || "").trim().slice(0, 500)
  if (q === "") return _escapeHtml(t)
  var words = q.toLowerCase().split(/\s+/).filter(Boolean)
  if (words.length === 0) return _escapeHtml(t)
  var highlightRe = new RegExp("(" + words.map(_escapeRegex).join("|") + ")", "gi")
  var color = String(accentColor)
  return _escapeHtml(t).replace(highlightRe, '<font color="' + color + '">$1</font>')
}

// Reveal-more threshold shared by QuranTab.qml and HadithTab.qml: true once the
// view is scrolled to within 20 % of the bottom of the scrollable range. Kept
// in one place so both tabs' onContentYChanged handlers stay in sync.
function shouldRevealMore(contentY, contentHeight, viewHeight) {
  var scrollable = contentHeight - viewHeight
  return scrollable > 0 && contentY >= scrollable * 0.2
}

// Node-only exports. In QML `module` is undefined so this block is skipped;
// it exists so Node tests can `require("./search.js")`.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    _normalizeArabic: _normalizeArabic,
    _matchesText: _matchesText,
    searchAyahs: searchAyahs,
    searchByReference: searchByReference,
    searchHadiths: searchHadiths,
    buildCorpus: buildCorpus,
    buildIdf: buildIdf,
    buildHadithCorpus: buildHadithCorpus,
    prefixMatches: prefixMatches,
    suggestReferences: suggestReferences,
    highlightQuery: highlightQuery
  }
}
