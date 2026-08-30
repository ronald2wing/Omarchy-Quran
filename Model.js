// Model.js — Data access helpers, daily ayah selection, and shared utilities.
// Platform-free: loaded via `import "Model.js" as Model`
// in QML and `require("./Model.js")` in Node tests.
//
// The reference engine is the `Quran` namespace (Quran.js). In QML it resolves
// to the importing document's `import "Quran.js" as Quran`, so Model.js
// deliberately does NOT declare `var Quran` — a local declaration would shadow
// that namespace. Node has no document scope, so require() it here; the bare
// assignment (no `var`) keeps the QML namespace unshadowed, and the global it
// creates under Node is never seen by the QML engine.
if (typeof module !== "undefined" && module.exports) {
  Quran = require("./Quran.js")
}

// Convert a file:// URL to an absolute filesystem path. Used by Shell.qml,
// PrayerService.qml, and HadithTab.qml when resolving Qt.resolvedUrl() results
// for FileView paths.
function fileUrlToPath(url) {
  var s = String(url || "")
  try { s = decodeURIComponent(s) } catch (e) { /* leave raw if decode fails */ }
  if (s.indexOf("file://") === 0) s = s.slice(7)
  if (s.length > 0 && s.charAt(0) !== "/") s = "/" + s
  // Collapse '.' and '..' segments so a malicious / crafted path like
  // "file:///home/user/../../etc/passwd" cannot escape the intended tree.
  var parts = s.split("/")
  var stack = []
  for (var i = 0; i < parts.length; i++) {
    if (parts[i] === "..") { stack.pop() }
    else if (parts[i] !== "" && parts[i] !== ".") { stack.push(parts[i]) }
  }
  s = "/" + stack.join("/")
  return s
}

var TOTAL_AYAHS = 6236

// --- Data access ------------------------------------------------------------

// [{ n, ar, en }, ...] for one surah, or [] if the data isn't loaded / found.
function ayahsFor(data, surahId) {
  if (!data || !data.surahs) return []
  var s = data.surahs[surahId - 1]
  if (!s || s.id !== surahId) {
    s = null
    for (var i = 0; i < data.surahs.length; i++) {
      if (data.surahs[i].id === surahId) { s = data.surahs[i]; break }
    }
  }
  return s ? s.ayahs : []
}

// The basmala opens every surah except 9 (and 1, where it is ayah 1 itself).
// In the bundled text it is prepended to the first ayah, so split it out for
// display: basmalaFor() returns the basmala string, arabicFor() returns the
// ayah text with the basmala prefix removed. The basmala is always the first
// four space-separated words, so no brittle character matching is needed.
var BASMALA_RE = /^ب(?:ّ)?ِسْمِ/

function basmalaFor(data, surahId) {
  if (surahId === 1 || surahId === 9) return ""
  var ayahs = ayahsFor(data, surahId)
  if (!ayahs || ayahs.length === 0) return ""
  var words = (ayahs[0].ar || "").split(" ")
  if (words.length < 4 || !BASMALA_RE.test(words[0])) return ""
  return words.slice(0, 4).join(" ")
}

function arabicFor(data, surahId, ayahN, text) {
  if (ayahN === 1) {
    var b = basmalaFor(data, surahId)
    if (b) return String(text).slice(b.length).replace(/^\s+/, "").trim()
  }
  return text
}

// --- Daily ayah (deterministic per ISO date) ---------------------------------

// FNV-1a 32-bit hash, pure ES5. The shift/add form multiplies by the FNV prime
// (2^24 + 2^8 + 2^7 + 2^4 + 2 + 1) without relying on Math.imul, which is not
// guaranteed in the QML JS engine.
function fnv1a(str) {
  var hash = 2166136261
  var s = String(str || "")
  for (var i = 0; i < s.length; i++) {
    hash ^= s.charCodeAt(i)
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24)
  }
  return hash >>> 0
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function isoDate(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function ayahIndexForDate(date) {
  return fnv1a(isoDate(date)) % TOTAL_AYAHS
}

// { surahId, ayahN } for a 0-6235 index into the flattened ayah list.
function referenceForIndex(data, flatIndex) {
  if (!data || !Array.isArray(data.surahs)) return { surahId: 1, ayahN: 1 }
  for (var i = 0; i < data.surahs.length; i++) {
    var s = data.surahs[i]
    var count = s.ayahs ? s.ayahs.length : 0
    if (flatIndex < count) return { surahId: s.id, ayahN: flatIndex + 1 }
    flatIndex -= count
  }
  return { surahId: 1, ayahN: 1 }
}

function dailyAyahReference(data, date) {
  var ref = referenceForIndex(data, ayahIndexForDate(date))
  var ayahs = ayahsFor(data, ref.surahId)
  var a = ayahs[ref.ayahN - 1] || { ar: "", en: "" }
  return {
    reference: ref,
    arabic: a.ar || "",
    english: a.en || "",
    referenceLabel: Quran.formatRefLocalized(ref.surahId, ref.ayahN, "english")
  }
}

// --- Hadith utilities --------------------------------------------------------

// The sixteen collections bundled as data/hadith/{id}.json (eng + ara pre-merged).
// Ordered in the traditional Sunni sequence: the Kutub al-Sittah plus Muwatta
// Malik and Musnad Ahmad, then supplementary collections.
var COLLECTIONS = [
  { id: "bukhari",  name: "Sahih al-Bukhari",                        name_ar: "صحيح البخاري",                        author: "Imam Muhammad ibn Ismail al-Bukhari" },
  { id: "muslim",   name: "Sahih Muslim",                            name_ar: "صحيح مسلم",                          author: "Imam Muslim ibn al-Hajjaj" },
  { id: "tirmidhi", name: "Jami at-Tirmidhi",                        name_ar: "جامع الترمذي",                        author: "Imam Abu Isa Muhammad al-Tirmidhi" },
  { id: "abudawud", name: "Sunan Abu Dawud",                         name_ar: "سنن أبي داود",                        author: "Imam Abu Dawud al-Sijistani" },
  { id: "nasai",    name: "Sunan an-Nasa'i",                         name_ar: "سنن النسائي",                         author: "Imam Ahmad ibn Shu'ayb al-Nasa'i" },
  { id: "ibnmajah", name: "Sunan Ibn Majah",                         name_ar: "سنن ابن ماجه",                        author: "Imam Muhammad ibn Yazid Ibn Majah" },
  { id: "malik",    name: "Muwatta Malik",                           name_ar: "موطأ مالك",                           author: "Imam Malik ibn Anas" },
  { id: "ahmad",    name: "Musnad Ahmad",                            name_ar: "مسند أحمد",                           author: "Imam Ahmad ibn Hanbal" },
  { id: "darimi",   name: "Sunan ad-Darimi",                         name_ar: "سنن الدارمي",                         author: "Imam Abdullah ibn Abd al-Rahman al-Darimi" },
  { id: "nawawi",   name: "Riyad as-Salihin",                        name_ar: "رياض الصالحين",                       author: "Imam Yahya ibn Sharaf al-Nawawi" },
  { id: "adab",     name: "Al-Adab Al-Mufrad",                       name_ar: "الأدب المفرد",                        author: "Imam Muhammad ibn Ismail al-Bukhari" },
  { id: "shamail",  name: "Shamail al-Muhammadiyah",                 name_ar: "الشمائل المحمدية",                    author: "Imam Abu Isa Muhammad al-Tirmidhi" },
  { id: "bulugh",   name: "Bulugh al-Maram",                         name_ar: "بلوغ المرام",                         author: "Imam Ibn Hajar al-Asqalani" },
  { id: "mishkat",  name: "Mishkat al-Masabih",                      name_ar: "مشكاة المصابيح",                      author: "Imam Waliuddin Abu Abdullah al-Khatib al-Tabrizi" },
  { id: "qudsi",    name: "Forty Hadith Qudsi",                      name_ar: "الأربعون القدسية",                    author: "Various" },
  { id: "dehlawi",  name: "Forty Hadith of Shah Waliullah Dehlawi",  name_ar: "الأربعون للدهلوي",                    author: "Shah Waliullah Dehlawi" }
]

function collectionIndex(id) {
  for (var i = 0; i < COLLECTIONS.length; i++) {
    if (COLLECTIONS[i].id === id) return i
  }
  return -1
}

function collectionName(collection, language) {
  var i = collectionIndex(collection)
  if (i >= 0) {
    return (language === "arabic" && COLLECTIONS[i].name_ar)
      ? COLLECTIONS[i].name_ar
      : COLLECTIONS[i].name
  }
  return String(collection || "")
}

// Pick the localized variant of an en/ar value pair. When the UI language is
// arabic and an arabic string exists, return it; otherwise fall back to the
// english value. Shared by HadithTab.qml for chapter/book/collection labels.
function localizedName(enValue, arValue, language) {
  return language === "arabic" && arValue ? arValue : enValue
}

// Resolve the next fajr/dhuhr/asr/maghrib/isha prayer name for the given
// computePrayerTimes result and Date (or now). Sunrise is excluded — it is
// a time marker, not a prayer, and must not trigger a notification.
// Shared by PrayerService.qml (alert detection) and HomePage.qml (countdown + highlight)
// so the logic and the HH:MM string-comparison rules stay canonical in one place.
function nextPrayerName(times, date) {
  if (!times || !times.fajr) return ""
  var d = date || new Date()
  var h = pad2(d.getHours())
  var m = pad2(d.getMinutes())
  var hm = h + ":" + m
  if (hm < times.fajr) return "fajr"
  if (hm < times.dhuhr) return "dhuhr"
  if (hm < times.asr) return "asr"
  if (hm < times.maghrib) return "maghrib"
  if (hm < times.isha) return "isha"
  return "fajr"
}

// Node-only exports. In QML `module` is undefined so this block is skipped;
// it exists so Node tests can `require("./Model.js")`.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    fileUrlToPath: fileUrlToPath,
    ayahsFor: ayahsFor,
    basmalaFor: basmalaFor,
    arabicFor: arabicFor,
    dailyAyahReference: dailyAyahReference,
    COLLECTIONS: COLLECTIONS,
    collectionIndex: collectionIndex,
    collectionName: collectionName,
    localizedName: localizedName,
    nextPrayerName: nextPrayerName
  }
}
