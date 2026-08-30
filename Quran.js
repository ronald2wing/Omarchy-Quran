// Quran.js — Surah metadata and reference engine.
// Platform-free: loaded via `import "Quran.js" as Quran` in QML and
// `require("./Quran.js")` in Node tests.
// Surah metadata (114 entries) used for reference parsing, navigation, and formatting.
// BEGIN SURAHS
var SURAHS = [
  { id: 1, name_ar: "الفاتحة", name_translit: "Al-Fatihah", ayahCount: 7 },
  { id: 2, name_ar: "البقرة", name_translit: "Al-Baqarah", ayahCount: 286 },
  { id: 3, name_ar: "آل عمران", name_translit: "Aal-i-Imran", ayahCount: 200 },
  { id: 4, name_ar: "النساء", name_translit: "An-Nisa", ayahCount: 176 },
  { id: 5, name_ar: "المائدة", name_translit: "Al-Maidah", ayahCount: 120 },
  { id: 6, name_ar: "الأنعام", name_translit: "Al-Anam", ayahCount: 165 },
  { id: 7, name_ar: "الأعراف", name_translit: "Al-Araf", ayahCount: 206 },
  { id: 8, name_ar: "الأنفال", name_translit: "Al-Anfal", ayahCount: 75 },
  { id: 9, name_ar: "التوبة", name_translit: "At-Tawbah", ayahCount: 129 },
  { id: 10, name_ar: "يونس", name_translit: "Yunus", ayahCount: 109 },
  { id: 11, name_ar: "هود", name_translit: "Hud", ayahCount: 123 },
  { id: 12, name_ar: "يوسف", name_translit: "Yusuf", ayahCount: 111 },
  { id: 13, name_ar: "الرعد", name_translit: "Ar-Rad", ayahCount: 43 },
  { id: 14, name_ar: "ابراهيم", name_translit: "Ibrahim", ayahCount: 52 },
  { id: 15, name_ar: "الحجر", name_translit: "Al-Hijr", ayahCount: 99 },
  { id: 16, name_ar: "النحل", name_translit: "An-Nahl", ayahCount: 128 },
  { id: 17, name_ar: "الإسراء", name_translit: "Al-Isra", ayahCount: 111 },
  { id: 18, name_ar: "الكهف", name_translit: "Al-Kahf", ayahCount: 110 },
  { id: 19, name_ar: "مريم", name_translit: "Maryam", ayahCount: 98 },
  { id: 20, name_ar: "طه", name_translit: "Ta-Ha", ayahCount: 135 },
  { id: 21, name_ar: "الأنبياء", name_translit: "Al-Anbiya", ayahCount: 112 },
  { id: 22, name_ar: "الحج", name_translit: "Al-Hajj", ayahCount: 78 },
  { id: 23, name_ar: "المؤمنون", name_translit: "Al-Muminun", ayahCount: 118 },
  { id: 24, name_ar: "النور", name_translit: "An-Nur", ayahCount: 64 },
  { id: 25, name_ar: "الفرقان", name_translit: "Al-Furqan", ayahCount: 77 },
  { id: 26, name_ar: "الشعراء", name_translit: "Ash-Shuara", ayahCount: 227 },
  { id: 27, name_ar: "النمل", name_translit: "An-Naml", ayahCount: 93 },
  { id: 28, name_ar: "القصص", name_translit: "Al-Qasas", ayahCount: 88 },
  { id: 29, name_ar: "العنكبوت", name_translit: "Al-Ankabut", ayahCount: 69 },
  { id: 30, name_ar: "الروم", name_translit: "Ar-Rum", ayahCount: 60 },
  { id: 31, name_ar: "لقمان", name_translit: "Luqman", ayahCount: 34 },
  { id: 32, name_ar: "السجدة", name_translit: "As-Sajdah", ayahCount: 30 },
  { id: 33, name_ar: "الأحزاب", name_translit: "Al-Ahzab", ayahCount: 73 },
  { id: 34, name_ar: "سبإ", name_translit: "Saba", ayahCount: 54 },
  { id: 35, name_ar: "فاطر", name_translit: "Fatir", ayahCount: 45 },
  { id: 36, name_ar: "يس", name_translit: "Ya-Sin", ayahCount: 83 },
  { id: 37, name_ar: "الصافات", name_translit: "As-Saffat", ayahCount: 182 },
  { id: 38, name_ar: "ص", name_translit: "Sad", ayahCount: 88 },
  { id: 39, name_ar: "الزمر", name_translit: "Az-Zumar", ayahCount: 75 },
  { id: 40, name_ar: "غافر", name_translit: "Ghafir", ayahCount: 85 },
  { id: 41, name_ar: "فصلت", name_translit: "Fussilat", ayahCount: 54 },
  { id: 42, name_ar: "الشورى", name_translit: "Ash-Shura", ayahCount: 53 },
  { id: 43, name_ar: "الزخرف", name_translit: "Az-Zukhruf", ayahCount: 89 },
  { id: 44, name_ar: "الدخان", name_translit: "Ad-Dukhan", ayahCount: 59 },
  { id: 45, name_ar: "الجاثية", name_translit: "Al-Jathiyah", ayahCount: 37 },
  { id: 46, name_ar: "الأحقاف", name_translit: "Al-Ahqaf", ayahCount: 35 },
  { id: 47, name_ar: "محمد", name_translit: "Muhammad", ayahCount: 38 },
  { id: 48, name_ar: "الفتح", name_translit: "Al-Fath", ayahCount: 29 },
  { id: 49, name_ar: "الحجرات", name_translit: "Al-Hujurat", ayahCount: 18 },
  { id: 50, name_ar: "ق", name_translit: "Qaf", ayahCount: 45 },
  { id: 51, name_ar: "الذاريات", name_translit: "Adh-Dhariyat", ayahCount: 60 },
  { id: 52, name_ar: "الطور", name_translit: "At-Tur", ayahCount: 49 },
  { id: 53, name_ar: "النجم", name_translit: "An-Najm", ayahCount: 62 },
  { id: 54, name_ar: "القمر", name_translit: "Al-Qamar", ayahCount: 55 },
  { id: 55, name_ar: "الرحمن", name_translit: "Ar-Rahman", ayahCount: 78 },
  { id: 56, name_ar: "الواقعة", name_translit: "Al-Waqiah", ayahCount: 96 },
  { id: 57, name_ar: "الحديد", name_translit: "Al-Hadid", ayahCount: 29 },
  { id: 58, name_ar: "المجادلة", name_translit: "Al-Mujadila", ayahCount: 22 },
  { id: 59, name_ar: "الحشر", name_translit: "Al-Hashr", ayahCount: 24 },
  { id: 60, name_ar: "الممتحنة", name_translit: "Al-Mumtahanah", ayahCount: 13 },
  { id: 61, name_ar: "الصف", name_translit: "As-Saff", ayahCount: 14 },
  { id: 62, name_ar: "الجمعة", name_translit: "Al-Jumuah", ayahCount: 11 },
  { id: 63, name_ar: "المنافقون", name_translit: "Al-Munafiqun", ayahCount: 11 },
  { id: 64, name_ar: "التغابن", name_translit: "At-Taghabun", ayahCount: 18 },
  { id: 65, name_ar: "الطلاق", name_translit: "At-Talaq", ayahCount: 12 },
  { id: 66, name_ar: "التحريم", name_translit: "At-Tahrim", ayahCount: 12 },
  { id: 67, name_ar: "الملك", name_translit: "Al-Mulk", ayahCount: 30 },
  { id: 68, name_ar: "القلم", name_translit: "Al-Qalam", ayahCount: 52 },
  { id: 69, name_ar: "الحاقة", name_translit: "Al-Haqqah", ayahCount: 52 },
  { id: 70, name_ar: "المعارج", name_translit: "Al-Maarij", ayahCount: 44 },
  { id: 71, name_ar: "نوح", name_translit: "Nuh", ayahCount: 28 },
  { id: 72, name_ar: "الجن", name_translit: "Al-Jinn", ayahCount: 28 },
  { id: 73, name_ar: "المزمل", name_translit: "Al-Muzzammil", ayahCount: 20 },
  { id: 74, name_ar: "المدثر", name_translit: "Al-Muddaththir", ayahCount: 56 },
  { id: 75, name_ar: "القيامة", name_translit: "Al-Qiyamah", ayahCount: 40 },
  { id: 76, name_ar: "الانسان", name_translit: "Al-Insan", ayahCount: 31 },
  { id: 77, name_ar: "المرسلات", name_translit: "Al-Mursalat", ayahCount: 50 },
  { id: 78, name_ar: "النبإ", name_translit: "An-Naba", ayahCount: 40 },
  { id: 79, name_ar: "النازعات", name_translit: "An-Naziat", ayahCount: 46 },
  { id: 80, name_ar: "عبس", name_translit: "Abasa", ayahCount: 42 },
  { id: 81, name_ar: "التكوير", name_translit: "At-Takwir", ayahCount: 29 },
  { id: 82, name_ar: "الإنفطار", name_translit: "Al-Infitar", ayahCount: 19 },
  { id: 83, name_ar: "المطففين", name_translit: "Al-Mutaffifin", ayahCount: 36 },
  { id: 84, name_ar: "الإنشقاق", name_translit: "Al-Inshiqaq", ayahCount: 25 },
  { id: 85, name_ar: "البروج", name_translit: "Al-Buruj", ayahCount: 22 },
  { id: 86, name_ar: "الطارق", name_translit: "At-Tariq", ayahCount: 17 },
  { id: 87, name_ar: "الأعلى", name_translit: "Al-Ala", ayahCount: 19 },
  { id: 88, name_ar: "الغاشية", name_translit: "Al-Ghashiyah", ayahCount: 26 },
  { id: 89, name_ar: "الفجر", name_translit: "Al-Fajr", ayahCount: 30 },
  { id: 90, name_ar: "البلد", name_translit: "Al-Balad", ayahCount: 20 },
  { id: 91, name_ar: "الشمس", name_translit: "Ash-Shams", ayahCount: 15 },
  { id: 92, name_ar: "الليل", name_translit: "Al-Layl", ayahCount: 21 },
  { id: 93, name_ar: "الضحى", name_translit: "Ad-Duhaa", ayahCount: 11 },
  { id: 94, name_ar: "الشرح", name_translit: "Ash-Sharh", ayahCount: 8 },
  { id: 95, name_ar: "التين", name_translit: "At-Tin", ayahCount: 8 },
  { id: 96, name_ar: "العلق", name_translit: "Al-Alaq", ayahCount: 19 },
  { id: 97, name_ar: "القدر", name_translit: "Al-Qadr", ayahCount: 5 },
  { id: 98, name_ar: "البينة", name_translit: "Al-Bayyinah", ayahCount: 8 },
  { id: 99, name_ar: "الزلزلة", name_translit: "Az-Zalzalah", ayahCount: 8 },
  { id: 100, name_ar: "العاديات", name_translit: "Al-Adiyat", ayahCount: 11 },
  { id: 101, name_ar: "القارعة", name_translit: "Al-Qariah", ayahCount: 11 },
  { id: 102, name_ar: "التكاثر", name_translit: "At-Takathur", ayahCount: 8 },
  { id: 103, name_ar: "العصر", name_translit: "Al-Asr", ayahCount: 3 },
  { id: 104, name_ar: "الهمزة", name_translit: "Al-Humazah", ayahCount: 9 },
  { id: 105, name_ar: "الفيل", name_translit: "Al-Fil", ayahCount: 5 },
  { id: 106, name_ar: "قريش", name_translit: "Quraysh", ayahCount: 4 },
  { id: 107, name_ar: "الماعون", name_translit: "Al-Maun", ayahCount: 7 },
  { id: 108, name_ar: "الكوثر", name_translit: "Al-Kawthar", ayahCount: 3 },
  { id: 109, name_ar: "الكافرون", name_translit: "Al-Kafirun", ayahCount: 6 },
  { id: 110, name_ar: "النصر", name_translit: "An-Nasr", ayahCount: 3 },
  { id: 111, name_ar: "المسد", name_translit: "Al-Masad", ayahCount: 5 },
  { id: 112, name_ar: "الإخلاص", name_translit: "Al-Ikhlas", ayahCount: 4 },
  { id: 113, name_ar: "الفلق", name_translit: "Al-Falaq", ayahCount: 5 },
  { id: 114, name_ar: "الناس", name_translit: "An-Nas", ayahCount: 6 },
]
// END SURAHS

var DEFAULT_SURAH = 1
var DEFAULT_AYAH = 1

// Common alternate transliterations (and Arabic spellings) that don't match
// the canonical name_translit above. Keys are normalized by _collapseKey().
var ALIAS_EXTRAS = {
  "fateha": 1, "fatehah": 1, "fatiha": 1, "fatihah": 1,
  "baqara": 2, "baqra": 2, "bakara": 2, "bakarah": 2,
  "aalimran": 3, "aaleimran": 3, "aleimran": 3, "aliimran": 3, "imran": 3,
  "nisa": 4, "nissa": 4, "nisaa": 4, "nisa'a": 4,
  "maida": 5, "maidah": 5, "ma'ida": 5, "ma'idah": 5,
  "anam": 6, "an'am": 6, "an-am": 6,
  "araf": 7, "a'raf": 7, "al-a'raf": 7,
  "anfal": 8,
  "tawba": 9, "tawbah": 9, "taubah": 9, "tauba": 9, "baraat": 9,
  "younus": 10, "younis": 10, "yunis": 10, "younes": 10,
  "yousef": 12, "yusef": 12, "yusuf": 12,
  "rad": 13, "ra'd": 13, "raad": 13,
  "ibrahem": 14, "abrahem": 14, "ibrahim": 14,
  "nahl": 16,
  "isra": 17, "israa": 17, "baniisrael": 17, "baniisrail": 17,
  "kahf": 18, "cave": 18,
  "mariam": 19, "mariyam": 19, "meryem": 19,
  "taha": 20, "taha'": 20,
  "anbiya": 21, "anbiyaa": 21, "anbiya'": 21,
  "muminun": 23, "muminoon": 23, "mu'minun": 23, "mumenoon": 23,
  "nur": 24, "noor": 24,
  "furqan": 25,
  "shuara": 26, "shu'ara": 26, "shuaraa": 26, "shu'araa": 26,
  "naml": 27,
  "qasas": 28,
  "ankabut": 29, "ankaboot": 29,
  "rum": 30, "room": 30, "arroom": 30,
  "lokman": 31, "luqman": 31,
  "sajda": 32, "sajdah": 32, "sajadah": 32,
  "ahzab": 33,
  "saba": 34, "sabaa": 34, "saba'": 34,
  "fater": 35, "fatir": 35,
  "yasin": 36, "yaseen": 36, "ya-sin": 36, "ya sin": 36,
  "saffat": 37, "as-saffat": 37,
  "saad": 38, "sad": 38,
  "zumar": 39, "zummar": 39,
  "gafer": 40, "ghafir": 40,
  "fusilat": 41, "fussilat": 41,
  "shura": 42, "shoora": 42,
  "zukhruf": 43,
  "dukhan": 44,
  "jathiya": 45, "jathiyah": 45, "jathiyyah": 45,
  "ahqaf": 46, "ahqaaf": 46,
  "fath": 48,
  "hujurat": 49, "hujuraat": 49,
  "qaf": 50,
  "dhariyat": 51, "zariyat": 51, "dhariyaat": 51, "zariyaat": 51,
  "tur": 52,
  "najm": 53,
  "qamar": 54,
  "rahman": 55, "alrahman": 55, "arrahmaan": 55,
  "waqia": 56, "waqiah": 56, "waqi'ah": 56, "waqiya": 56, "alwaqia": 56,
  "hadid": 57,
  "mujadila": 58, "mujadalah": 58, "mujadala": 58, "mujadilah": 58,
  "hashr": 59,
  "mumtahana": 60, "mumtahanah": 60, "mumtahina": 60, "mumtahinah": 60,
  "saff": 61,
  "jumuah": 62, "jumua": 62, "jumu'a": 62, "jumu'ah": 62,
  "munafiqun": 63, "munafiqoon": 63,
  "taghabun": 64, "taghaboon": 64,
  "talaq": 65,
  "tahrim": 66,
  "mulk": 67, "tabarak": 67, "almulk": 67,
  "qalam": 68,
  "haqqah": 69, "haqqa": 69, "haaqqa": 69,
  "maarij": 70, "ma'arij": 70,
  "nooh": 71, "nuh": 71,
  "jinn": 72,
  "muzzammil": 73,
  "muddaththir": 74, "muddathir": 74,
  "qiyamah": 75, "qiyama": 75, "qiyaamah": 75,
  "insan": 76, "insaan": 76, "al-insan": 76,
  "mursalat": 77,
  "naba": 78, "naba'": 78,
  "naziat": 79, "nazi'at": 79, "naziaat": 79,
  "abasa": 80,
  "takwir": 81,
  "infitar": 82, "infitaar": 82,
  "mutaffifin": 83, "mutaffifeen": 83,
  "inshiqaq": 84,
  "buruj": 85, "buruuj": 85,
  "tariq": 86,
  "ala": 87, "a'la": 87, "alaa": 87, "al-a'la": 87,
  "ghashiyah": 88, "ghashiya": 88,
  "fajr": 89,
  "balad": 90,
  "shams": 91,
  "layl": 92, "lail": 92, "laylah": 92, "al-layl": 92,
  "duha": 93, "duhaa": 93, "dhuha": 93, "ad-duha": 93, "ad-duhaa": 93,
  "sharh": 94, "inshirah": 94, "inshiraa": 94, "ash-sharh": 94,
  "tin": 95,
  "alaq": 96, "ala'q": 96, "iqra": 96, "iqraa": 96, "al-alaq": 96,
  "qadr": 97, "qadar": 97,
  "bayyina": 98, "bayyinah": 98,
  "zalzalah": 99, "zalzala": 99, "zalzalh": 99,
  "adiyat": 100, "adiyaat": 100, "al-adiyat": 100,
  "qaria": 101, "qariah": 101, "qari'ah": 101, "qari'at": 101, "al-qari'ah": 101,
  "takathur": 102, "takaathur": 102,
  "asr": 103, "al-asr": 103,
  "humazah": 104, "humaza": 104,
  "fil": 105,
  "quraish": 106, "qurays": 106, "qoraish": 106, "quraysh": 106,
  "maun": 107, "ma'un": 107, "maoon": 107, "al-ma'un": 107,
  "kawthar": 108, "kauthar": 108, "kausar": 108, "al-kawthar": 108,
  "kafirun": 109, "kafiroon": 109, "al-kafirun": 109, "al-kafiroon": 109,
  "nasr": 110, "an-nasr": 110,
  "masad": 111, "lahab": 111, "al-masad": 111, "al-lahab": 111,
  "ikhlas": 112, "iklas": 112, "al-ikhlas": 112, "al-iklas": 112,
  "falaq": 113, "al-falaq": 113,
  "naas": 114, "an-naas": 114
}

var _aliasToId = null
var _surahById = null

// Collapse for matching: lowercase, drop spaces/dashes/apostrophes, keep
// letters (including Arabic) and digits.
function _collapseKey(s) {
  return String(s || "")
    .toLowerCase()
    .replace(/[\s\-'’‘.]+/g, "")
}

// Fold Arabic text for matching: strip tashkeel (diacritics), superscript alef,
// and tatweel, then normalize alef/hamza/ta-marbuta/alef-maqsura variants. The
// caller chooses whether to strip a leading ال (surah-name lookup) or keep it
// (full-text search). Both call paths share this single implementation.
function foldArabic(text) {
  return String(text || "")
    .replace(/[\u064B-\u0652\u0670\u0640]/g, "")    // tashkeel + superscript alef + tatweel
    .replace(/[أإآٱ]/g, "ا")                        // alef/hamza variants → bare alef
    .replace(/ؤ/g, "و")                              // waw with hamza → waw
    .replace(/ئ/g, "ي")                              // yeh with hamza → yeh
    .replace(/ة/g, "ه")                              // ta marbuta → ha
    .replace(/ى/g, "ي")                              // alef maqsura → yeh
    .replace(/ء/g, "")                               // hamza → removed
}

// Strips Arabic diacritics and normalizes character variants, then removes a
// leading ال so surah-name lookups match regardless of the article.
function normalizeArabic(s) {
  return foldArabic(s).replace(/^ال/, "")
}

// Strip a leading article ("al", "el", "the", optionally dashed) so
// "al-baqarah", "Al-Baqarah", and "baqarah" resolve to the same surah.
function _stripLeadingArticle(s) {
  return String(s || "").replace(/^(?:al|el|the)-?/i, "")
}

function _ensureLookupIndexes() {
  if (_aliasToId) return
  _aliasToId = {}
  _surahById = {}
  var i, s, translitKey, arKey
  for (i = 0; i < SURAHS.length; i++) {
    s = SURAHS[i]
    _surahById[s.id] = s
    translitKey = _collapseKey(_stripLeadingArticle(s.name_translit))
    arKey = normalizeArabic(s.name_ar)
    _aliasToId[translitKey] = s.id
    _aliasToId[_collapseKey(s.name_translit)] = s.id
    _aliasToId[arKey] = s.id
    _aliasToId["al" + arKey] = s.id
  }
  for (var k in ALIAS_EXTRAS) {
    _aliasToId[_collapseKey(_stripLeadingArticle(k))] = ALIAS_EXTRAS[k]
    _aliasToId[normalizeArabic(k)] = ALIAS_EXTRAS[k]
  }
}

function surahById(id) {
  _ensureLookupIndexes()
  return _surahById[id] || null
}

function ayahCount(id) {
  var s = surahById(id)
  return s ? s.ayahCount : 0
}

// "2:255" -> { surahId: 2, ayahN: 255 }. Unknown surah/name -> null. Out-of-range
// ayahs are clamped to the surah (friendlier than rejecting).
function parseReference(input) {
  var raw = String(input || "").trim()
  if (!raw) return null

  // "2:255", "2 255", or "2.255" (separator required so "999" stays a
  // bare surah number, not "99:9")
  var numColon = raw.match(/^(\d{1,3})\s*[:.]\s*(\d{1,3})$/) || raw.match(/^(\d{1,3})\s+(\d{1,3})$/)
  if (numColon) {
    var s1 = surahById(parseInt(numColon[1], 10))
    if (!s1) return null
    return { surahId: s1.id, ayahN: clampAyah(s1.id, parseInt(numColon[2], 10)) }
  }

  // bare surah number: "2"
  var numOnly = raw.match(/^(\d{1,3})$/)
  if (numOnly) {
    var s2 = surahById(parseInt(numOnly[1], 10))
    if (!s2) return null
    return { surahId: s2.id, ayahN: 1 }
  }

  // name + number: "al-baqarah 255", "baqarah 255", "البقرة 255", "baqarah255"
  var m = raw.match(/^(.+?)\s+(\d{1,3})$/)
  var namePart = raw
  var ayahNum = 1
  if (m) {
    namePart = m[1]
    ayahNum = parseInt(m[2], 10)
  } else {
    var glued = raw.match(/^([^\d]+?)(\d{1,3})$/)
    if (glued) {
      namePart = glued[1]
      ayahNum = parseInt(glued[2], 10)
    }
  }

  _ensureLookupIndexes()
  var id = _aliasToId[_collapseKey(_stripLeadingArticle(namePart))]
  if (!id) id = _aliasToId[normalizeArabic(namePart)]
  if (!id) return null
  return { surahId: id, ayahN: clampAyah(id, ayahNum) }
}

function clampAyah(surahId, ayah) {
  var count = ayahCount(surahId)
  if (count <= 0) return 1
  if (ayah < 1) return 1
  if (ayah > count) return count
  return ayah
}

// Surah name in the active UI language. "arabic" → name_ar, otherwise name_translit.
function surahName(surahId, language) {
  var s = surahById(surahId)
  if (!s) return String(surahId || "")
  return (language === "arabic") ? s.name_ar : s.name_translit
}

// Language-aware format: in Arabic mode, surah name is Arabic; with no language
// (or "english") it renders the transliterated name, e.g. "Al-Baqarah 2:255".
function formatRefLocalized(surahId, ayah, language) {
  var name = surahName(surahId, language)
  if (!ayah) return name
  return name + " " + surahId + ":" + ayah
}

function nextAyah(surahId, ayah) {
  var s = surahById(surahId)
  if (!s) return { surahId: DEFAULT_SURAH, ayahN: DEFAULT_AYAH }
  if (ayah < s.ayahCount) return { surahId: surahId, ayahN: ayah + 1 }
  var next = surahId < SURAHS.length ? surahId + 1 : 1
  return { surahId: next, ayahN: 1 }
}

function prevAyah(surahId, ayah) {
  if (ayah > 1) return { surahId: surahId, ayahN: ayah - 1 }
  var prev = surahId > 1 ? surahId - 1 : SURAHS.length
  var s = surahById(prev)
  return { surahId: prev, ayahN: s ? s.ayahCount : 1 }
}

function nextSurah(surahId) {
  if (!surahById(surahId)) return DEFAULT_SURAH
  return surahId < SURAHS.length ? surahId + 1 : 1
}

function prevSurah(surahId) {
  if (!surahById(surahId)) return DEFAULT_SURAH
  return surahId > 1 ? surahId - 1 : SURAHS.length
}

// Node-only exports. In QML `module` is undefined so this block is skipped;
// it exists so Node tests can `require("./Quran.js")`.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    SURAHS: SURAHS,
    ALIAS_EXTRAS: ALIAS_EXTRAS,
    DEFAULT_SURAH: DEFAULT_SURAH,
    DEFAULT_AYAH: DEFAULT_AYAH,
    foldArabic: foldArabic,
    surahById: surahById,
    parseReference: parseReference,
    clampAyah: clampAyah,
    formatRefLocalized: formatRefLocalized,
    nextAyah: nextAyah,
    prevAyah: prevAyah,
    nextSurah: nextSurah,
    prevSurah: prevSurah
  }
}
