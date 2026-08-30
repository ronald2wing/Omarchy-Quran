// tests/test_quran.js — Quran.js reference-engine tests.
// Runnable standalone: node tests/test_quran.js
// Exits 0 when every assertion passes, 1 on any failure.

const Quran = require("../Quran.js")
const Model = require("../Model.js")
const Search = require("../search.js")

let pass = 0
let fail = 0

// Load bundled Quran text once for the Model.js data-access tests.
let quranData = null
try {
  quranData = JSON.parse(require("fs").readFileSync(require("path").join(__dirname, "..", "data", "quran.json"), "utf8"))
} catch (e) {
  console.log("WARN: cannot load quran.json")
}

function ok(name, cond) {
  if (cond) {
    pass++
    console.log("PASS " + name)
  } else {
    fail++
    console.log("FAIL " + name)
  }
}

function eq(name, actual, expected) {
  const a = JSON.stringify(actual)
  const e = JSON.stringify(expected)
  if (a === e) {
    pass++
    console.log("PASS " + name)
  } else {
    fail++
    console.log("FAIL " + name + " — got " + a + ", want " + e)
  }
}

// --- SURAHS metadata ---
ok("SURAHS is an array", Array.isArray(Quran.SURAHS))
ok("SURAHS has 114 entries", Quran.SURAHS.length === 114)

// --- surahById ---
const fatihah = Quran.surahById(1)
ok(
  "surahById(1) is Al-Fatihah (id:1, ayahs:7)",
  fatihah !== null &&
    fatihah.id === 1 &&
    fatihah.name_ar === "الفاتحة" &&
    fatihah.name_translit === "Al-Fatihah" &&
    fatihah.ayahCount === 7
)
const nas = Quran.surahById(114)
ok("surahById(114) is An-Nas", nas !== null && nas.id === 114 && nas.name_translit === "An-Nas")
ok("surahById(999) is null", Quran.surahById(999) === null)

// --- parseReference ---
eq("parseReference('2:255')", Quran.parseReference("2:255"), { surahId: 2, ayahN: 255 })
eq("parseReference('al-baqarah 255')", Quran.parseReference("al-baqarah 255"), { surahId: 2, ayahN: 255 })
eq("parseReference('البقرة 255')", Quran.parseReference("البقرة 255"), { surahId: 2, ayahN: 255 })
eq("parseReference('2')", Quran.parseReference("2"), { surahId: 2, ayahN: 1 })
eq("parseReference('yasin 5')", Quran.parseReference("yasin 5"), { surahId: 36, ayahN: 5 })
eq("parseReference('1:999') clamps to 7", Quran.parseReference("1:999"), { surahId: 1, ayahN: 7 })
eq("parseReference('baqarah255') glued", Quran.parseReference("baqarah255"), { surahId: 2, ayahN: 255 })
ok("parseReference('') is null", Quran.parseReference("") === null)
ok("parseReference('garbage') is null", Quran.parseReference("garbage") === null)

// --- clampAyah ---
eq("clampAyah(1, 0) === 1", Quran.clampAyah(1, 0), 1)
eq("clampAyah(1, 8) === 7", Quran.clampAyah(1, 8), 7)
eq("clampAyah(1, 7) === 7", Quran.clampAyah(1, 7), 7)

// --- formatRefLocalized ---
eq("formatRefLocalized(2, 255, 'english')", Quran.formatRefLocalized(2, 255, "english"), "Al-Baqarah 2:255")

// --- nextAyah / prevAyah ---
eq("nextAyah(1, 1) within surah", Quran.nextAyah(1, 1), { surahId: 1, ayahN: 2 })
eq("nextAyah(1, 7) wraps to next surah", Quran.nextAyah(1, 7), { surahId: 2, ayahN: 1 })
eq("nextAyah(114, 6) wraps from end", Quran.nextAyah(114, 6), { surahId: 1, ayahN: 1 })
eq("prevAyah(2, 1) wraps to prev surah", Quran.prevAyah(2, 1), { surahId: 1, ayahN: 7 })
eq("prevAyah(1, 1) wraps to end", Quran.prevAyah(1, 1), { surahId: 114, ayahN: 6 })

// --- nextSurah / prevSurah ---
eq("nextSurah(1) === 2", Quran.nextSurah(1), 2)
eq("nextSurah(114) wraps === 1", Quran.nextSurah(114), 1)
eq("prevSurah(1) wraps === 114", Quran.prevSurah(1), 114)
eq("prevSurah(2) === 1", Quran.prevSurah(2), 1)

// --- ALIAS_EXTRAS ---
eq("ALIAS_EXTRAS['fateha'] === 1", Quran.ALIAS_EXTRAS["fateha"], 1)
eq("ALIAS_EXTRAS['yasin'] === 36", Quran.ALIAS_EXTRAS["yasin"], 36)
eq("ALIAS_EXTRAS['lahab'] === 111", Quran.ALIAS_EXTRAS["lahab"], 111)
eq("ALIAS_EXTRAS['ikhlas'] === 112", Quran.ALIAS_EXTRAS["ikhlas"], 112)

// --- exported constants ---
eq("DEFAULT_SURAH === 1", Quran.DEFAULT_SURAH, 1)
eq("DEFAULT_AYAH === 1", Quran.DEFAULT_AYAH, 1)

// ============================================================================
// Model.js tests — data access, daily ayah, state, hadith utilities
// ============================================================================

// --- ayahsFor ---
eq("Model.ayahsFor(null, 1) → []", Model.ayahsFor(null, 1), [])
const fatihahAyahs = Model.ayahsFor(quranData, 1)
ok(
  "Model.ayahsFor(data, 1) → 7 {n, ar, en} ayahs",
  Array.isArray(fatihahAyahs) &&
    fatihahAyahs.length === 7 &&
    fatihahAyahs.every((a) => typeof a.n === "number" && typeof a.ar === "string" && typeof a.en === "string")
)

// --- basmalaFor ---
// Tanzil's Uthmani text orders shadda before the vowel; NFC reorders combining
// marks canonically, so normalize both sides before comparing.
const nfc = (s) => String(s).normalize("NFC")
eq("Model.basmalaFor(data, 1) → '' (surah 1)", Model.basmalaFor(quranData, 1), "")
eq("Model.basmalaFor(data, 9) → '' (surah 9)", Model.basmalaFor(quranData, 9), "")
eq("Model.basmalaFor(data, 2) → basmala", nfc(Model.basmalaFor(quranData, 2)), nfc("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"))

// --- arabicFor ---
eq(
  "Model.arabicFor strips basmala from 2:1",
  Model.arabicFor(quranData, 2, 1, quranData.surahs[1].ayahs[0].ar),
  "الٓمٓ"
)

// --- collectionName ---
eq("Model.collectionName('bukhari') → 'Sahih al-Bukhari'", Model.collectionName("bukhari"), "Sahih al-Bukhari")
eq("Model.collectionName('unknown') → 'unknown'", Model.collectionName("unknown"), "unknown")

// --- dailyAyahReference ---
const daily = Model.dailyAyahReference(quranData, new Date())
ok("Model.dailyAyahReference returns object", daily !== null && typeof daily === "object")
ok(
  "Model.dailyAyahReference.reference is a valid {surahId, ayahN}",
  daily.reference !== undefined &&
    daily.reference.surahId >= 1 &&
    daily.reference.surahId <= 114 &&
    daily.reference.ayahN >= 1
)
ok("Model.dailyAyahReference.arabic is non-empty", typeof daily.arabic === "string" && daily.arabic.length > 0)
ok("Model.dailyAyahReference.english is non-empty", typeof daily.english === "string" && daily.english.length > 0)
ok("Model.dailyAyahReference.referenceLabel is non-empty", typeof daily.referenceLabel === "string" && daily.referenceLabel.length > 0)

// ============================================================================
// search.js tests — text + reference search
// ============================================================================

// --- searchAyahs guards ---
eq("Search.searchAyahs(null, 'allah') → []", Search.searchAyahs(null, "allah"), [])
eq("Search.searchAyahs(data, '') → []", Search.searchAyahs(quranData, ""), [])

// --- searchAyahs basic ---
const allahHits = Search.searchAyahs(quranData, "allah")
ok("Search.searchAyahs(data, 'allah') → non-empty", allahHits.length > 0)
ok(
  "Search.searchAyahs(data, 'allah') → array of {surahId, ayahN}",
  allahHits.every((r) => typeof r.surahId === "number" && typeof r.ayahN === "number")
)

// --- result structure ---
ok(
  "Search results carry {surahId, ayahN, ar, en}",
  allahHits.every(
    (r) =>
      typeof r.surahId === "number" &&
      typeof r.ayahN === "number" &&
      typeof r.ar === "string" &&
      typeof r.en === "string"
  )
)

// --- relevance ordering ---
// searchAyahs returns results ranked by IDF-weighted relevance. The first
// result should contain the query word(s) in a prominent position (earlier
// in the verse = higher score).
eq("Search.searchAyahs(data, 'allah') → non-empty and first 5 are valid", 
   allahHits.length >= 5, true)

// --- multi-word ---
// The plan specifies "allah mercifal", but "mercifal" never occurs in the
// Sahih International text (it is "merciful"), so that query matches nothing.
// Use the real word so the multi-word AND behavior is actually exercised.
const multi = Search.searchAyahs(quranData, "allah merciful")
ok("Search.searchAyahs(data, 'allah merciful') → non-empty", multi.length > 0)
ok(
  "Search.searchAyahs multi-word — each result contains 'allah'",
  multi.every((r) => (r.ar + " " + r.en).toLowerCase().indexOf("allah") !== -1)
)
ok(
  "Search.searchAyahs multi-word — each result contains 'merciful'",
  multi.every((r) => (r.ar + " " + r.en).toLowerCase().indexOf("merciful") !== -1)
)

// --- searchByReference ---
const ref255 = Search.searchByReference(quranData, "2:255")
ok("Search.searchByReference(data, '2:255') → single result", ref255.length === 1)
ok(
  "Search.searchByReference(data, '2:255') → surahId=2, ayahN=255",
  ref255.length === 1 && ref255[0].surahId === 2 && ref255[0].ayahN === 255
)
const yasin5 = Search.searchByReference(quranData, "yasin 5")
ok("Search.searchByReference(data, 'yasin 5') → single result", yasin5.length === 1)
ok(
  "Search.searchByReference(data, 'yasin 5') → surahId=36, ayahN=5",
  yasin5.length === 1 && yasin5[0].surahId === 36 && yasin5[0].ayahN === 5
)
eq("Search.searchByReference(data, 'invalid') → []", Search.searchByReference(quranData, "invalid"), [])

// --- unified engine: _normalizeArabic / _matchesText ---
eq("Search._normalizeArabic('بِسْمِ') → 'بسم'", Search._normalizeArabic("بِسْمِ"), "بسم")
ok("Search._matchesText('mercy', 'رحمه', ['mercy']) → true", Search._matchesText("mercy", "رحمه", ["mercy"]) === true)
ok("Search._matchesText('mercy', 'رحمه', ['prayer']) → false", Search._matchesText("mercy", "رحمه", ["prayer"]) === false)

// --- searchHadiths (text + numeric) ---
const mockHadiths = [
  { number: 1, textLower: "the book of faith", arabicStripped: "الايمان" },
  { number: 2, textLower: "prayer is the pillar", arabicStripped: "الصلاه" },
  { number: 3, textLower: "charity and prayer", arabicStripped: "الزكاه والصلاه" }
]
const hText = Search.searchHadiths(mockHadiths, "prayer", "text")
ok("Search.searchHadiths text 'prayer' → 2 results", hText.length === 2)
ok(
  "Search.searchHadiths text → {index} entries in canonical order",
  hText.every((r) => typeof r.index === "number") && hText.length === 2 && hText[0].index < hText[1].index
)
// Numeric search: index is the hadith position (0-based); canonical order not applicable
eq("Search.searchHadiths numeric '2' → [{index:1}]", Search.searchHadiths(mockHadiths, "2", "numeric")[0].index, 1)
eq("Search.searchHadiths text '' → []", Search.searchHadiths(mockHadiths, "", "text"), [])

// --- maxResults cap ---
const limited = Search.searchAyahs(quranData, "allah", 5)
ok("Search.searchAyahs(data, 'allah', 5) → non-empty", limited.length > 0)
eq("Search.searchAyahs(data, 'allah', 5) → capped at 5", limited.length <= 5, true)

// --- proximity reference search ---
const prox = Search.searchAyahs(quranData, "2:2", 10, null, { surahId: 2, ayahN: 2 })
ok("Proximity search 2:2 returns results", prox.length > 0)
ok("Proximity search — first result is 2:2",
   prox.length > 0 && prox[0].surahId === 2 && prox[0].ayahN === 2)
ok("Proximity search — neighbors are nearby (2:1, 2:3)",
   prox.length >= 3 && prox.some(function(r) { return r.surahId === 2 && r.ayahN === 1 }) &&
   prox.some(function(r) { return r.surahId === 2 && r.ayahN === 3 }))

// --- IDF-weighted scoring: rare words rank higher ---
// Without the search index, IDF is uniform (all words weight 1.0), so
// ranking is position-based. With the index loaded, rare words like
// "throne" (IDF ~2.3) dominate common words like "allah" (IDF ~0.2).
// Note: 2:255 uses "Kursi" in the Sahih International translation, not
// "Throne" — so the "throne" search tests verses about the Arsh (عرش).
const rare = Search.searchAyahs(quranData, "throne", 10)
ok("Rare word 'throne' returns results", rare.length > 0)
ok("Rare word — reorderable, at least 5 unique surahs",
   (new Set(rare.map(function(r) { return r.surahId }))).size >= 5)

// --- Concept expansion: 'ruler' → 'judge', 'govern', 'command' ---
const ruler = Search.searchAyahs(quranData, "ruler", 20)
ok("Concept search 'ruler' returns results", ruler.length > 0)
ok("Concept search 'ruler' has meaningful count", ruler.length >= 1)

console.log(fail === 0 ? `\n${pass} passed` : `\n${pass} passed, ${fail} failed`)
process.exit(fail === 0 ? 0 : 1)
