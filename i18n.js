// i18n.js — UI string translations for Omarchy Quran Plugin.
// Platform-free: loaded via `import "i18n.js" as I18n` in QML and
// `require("./i18n.js")` in Node tests.
//
// Keys are defined in the `translations` map below.
//
//   I18n.get(key, language)       — plain string lookup
//   I18n.template(key, language, args) — parameterised string via {placeholder}
//   I18n.translateGrade(grade)    — Arabic rendering of Hadith authenticity grades
//
// English is the fallback locale. When language === "arabic" the "ar"
// column renders; otherwise "en".
//
// In QML:  `import "../i18n.js" as I18n`
// In Node: `const I18n = require("./i18n.js")`

var _map = {
  // --- Tab labels ---------------------------------------------------------
  "tab.ayat":   { en: "Ayat",   ar: "آيات" },
  "tab.quran":  { en: "Quran",  ar: "قرآن" },
  "tab.hadith": { en: "Hadith", ar: "حديث" },

  // --- Prayer times -------------------------------------------------------
  "tooltip.prayer":       { en: "[Prayer]", ar: "[صلاة]" },
  "tooltip.ayah":         { en: "[Ayah]",   ar: "[آية]" },
  "prayer.header":       { en: "Prayer Times",   ar: "مواقيت الصلاة" },
  "prayer.fajr":         { en: "Fajr",           ar: "الفجر" },
  "prayer.dhuhr":        { en: "Dhuhr",          ar: "الظهر" },
  "prayer.asr":          { en: "Asr",            ar: "العصر" },
  "prayer.maghrib":      { en: "Maghrib",        ar: "المغرب" },
  "prayer.isha":         { en: "Isha",           ar: "العشاء" },
  "prayer.countdown.in": { en: "{name} in {h}h {m}m", ar: "{name} بعد {h}س {m}د" },
  "prayer.countdown.min":{ en: "{name} in {m}m", ar: "{name} بعد {m}د" },
  "prayer.countdown.at": { en: "{name} at {time}", ar: "{name} الساعة {time}" },
  "prayer.na":           { en: "--:--",          ar: "--:--" },
  "adhan.sound":         { en: "Sound",          ar: "الصوت" },
  "adhan.on":            { en: "ON",             ar: "تشغيل" },
  "adhan.off":           { en: "OFF",            ar: "إيقاف" },
  "adhan.stopHint":      { en: "Click to stop adhan — active during prayer notifications", ar: "اضغط لإيقاف الأذان — ينشط أثناء تنبيهات الصلاة" },

  // --- Ayat of the Day ----------------------------------------------------
  "ayat.header":  { en: "Ayat of the Day",       ar: "آية اليوم" },
  "ayat.source":   { en: "Sahih International",   ar: "ترجمة صحيح الدولية" },
  "ayat.continue":{ en: "Continue Reading: ",    ar: "متابعة القراءة: " },

  // --- Search -------------------------------------------------------------
  "search.quran":         { en: "Search the Quran…",        ar: "ابحث في القرآن…" },
  "search.hadith":        { en: "Search {collection} hadith text or number…", ar: "ابحث في {collection}…" },
  "search.placeholder":   { en: "Surah:ayah or search text…", ar: "سورة:آية أو نص البحث…" },
  "search.searching":     { en: "Searching…",               ar: "جاري البحث…" },
  "search.matches":       { en: "{n} result{suffix}",       ar: "{n} نتيجة" },
  "search.noMatches":     { en: "No matches for: {query}",  ar: "لا توجد نتائج لـ: {query}" },
  "search.hint":          { en: "↑↓ Navigate · Enter Open", ar: "↑↓ تنقل · Enter فتح" },

  // --- Quran reader -------------------------------------------------------
  "quran.ayahOf":  { en: "Ayah {n}/{total}",     ar: "آية {n}/{total}" },
  "quran.ayah":    { en: "Ayah ",                ar: "آية " },
  "quran.goTo":    { en: "Go to verse",          ar: "اذهب إلى الآية" },

  // --- Hadith reader ------------------------------------------------------
  "hadith.collections": { en: "Collections",       ar: "المجموعات" },
  "hadith.chaptersOf":  { en: "{name} — Chapters", ar: "{name} — الأبواب" },
  "hadith.nChapters":   { en: "{n} chapters",      ar: "{n} باب" },
  "hadith.nCollections":{ en: "{n} collections",   ar: "{n} مجموعة" },
  "hadith.ofChapter":   { en: "{collection} \u00b7 Hadith {pos}/{len}", ar: "{collection} · حديث {pos}/{len}" },
  "hadith.result":      { en: "{book} \u00b7 Hadith {number}", ar: "{book} · حديث {number}" },
  "hadith.label":       { en: "Hadith ",          ar: "حديث " },
  "hadith.chapter":     { en: "Chapter",          ar: "باب" },
  "hadith.total":       { en: "Total",            ar: "المجموع" },

  // --- Notification -------------------------------------------------------
  "notify.title":  { en: "{name} Prayer",              ar: "صلاة {name}" },
  "notify.body":   { en: "It is time for {name} prayer.", ar: "حان وقت صلاة {name}." },
  "notify.stopHint": { en: "Click ✕ in Quran plugin to stop adhan", ar: "اضغط ✕ في إضافة القرآن لإيقاف الأذان" },

  // --- Grade badge --------------------------------------------------------
  "grade.bracket": { en: "[{grade}]", ar: "[{grade}]" },

  // --- Clipboard ----------------------------------------------------------
  "copy.feedback":  { en: "Copied — {label}", ar: "تم النسخ — {label}" },
  "copy.footer":    { en: "Omarchy Quran Plugin — https://github.com/ronald2wing/Omarchy-Quran",
                      ar: "إضافة القرآن لأوماركي — https://github.com/ronald2wing/Omarchy-Quran" }
}

// --- hadith grade translation ----------------------------------------------
// Hoisted grade map + regex (ES5 `var`), built once at module load rather than
// on every translateGrade call. Case-insensitive so grades match regardless of
// source capitalization.
var GRADE_MAP = {
  Sahih: "صحيح", Hasan: "حسن", Daif: "ضعيف",
  Mawdu: "موضوع", Gharib: "غريب", Isnaad: "إسناد",
  Lighairihi: "لغيره", Mutawatir: "متواتر", Mashhur: "مشهور",
  Munkar: "منكر", Shadh: "شاذ", Maqbul: "مقبول",
  Mardud: "مردود", Matruk: "متروك", Muallaq: "معلق",
  Mursal: "مرسل", Munqati: "منقطع", Mudallas: "مدلس",
  Mudraj: "مدرج", Mudtarib: "مضطرب", Maqlub: "مقلوب",
  Majhul: "مجهول", Mubham: "مبهم",
  Bukhari: "البخاري", Muslim: "مسلم"
}
var GRADE_RE = new RegExp("\\b(" + Object.keys(GRADE_MAP).join("|") + ")\\b", "gi")

// Translate a hadith grade string to the target language. Used by the
// shortGrade badge so grade terms (Sahih, Hasan, Daif, etc.) follow the
// active UI locale rather than always being English.
function translateGrade(grade, lang) {
  if (!grade || lang !== "arabic") return grade
  return String(grade).replace(GRADE_RE, function(m) {
    return GRADE_MAP[m] || m
  })
}

// Resolve a single key. Falls back to English if the language or key is missing.
function get(key, lang) {
  var entry = _map[key]
  if (!entry) return key
  var loc = (lang === "arabic") ? "ar" : "en"
  return entry[loc] || entry.en || key
}

// Template fill: "hello {name}" with { name: "Ali" } → "hello Ali"
function template(key, lang, args) {
  var str = get(key, lang)
  if (!args) return str
  return str.replace(/\{(\w+)\}/g, function(_, k) {
    return args[k] !== undefined ? String(args[k]) : "{" + k + "}"
  })
}

// Node exports — in QML `module` is undefined so this block is skipped.
if (typeof module !== "undefined" && module.exports) {
  module.exports = { get: get, template: template, translateGrade: translateGrade }
}