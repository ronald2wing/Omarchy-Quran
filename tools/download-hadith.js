// tools/download-hadith.js — Download and pre-parse all 16 hadith collections,
// merge English + Arabic, and save each as a compact data/hadith/{id}.json.
//
// Collections available in fawazahmed0/hadith-api are fetched from its separate
// eng- / ara- editions, which ship per-hadith grades. The rest (Musnad Ahmad,
// Sunan ad-Darimi, Riyad as-Salihin, Al-Adab Al-Mufrad, Shama'il Muhammadiyah,
// Bulugh al-Maram, Mishkat al-Masabih) come from AhmedBaset/hadith-json
// (a Sunnah.com scrape) with no per-hadith grades.
//
// Usage: node tools/download-hadith.js
// Output: data/hadith/{bukhari,muslim,...,dehlawi}.json (16 files)

var Model = require("../Model.js")
var https = require("https")
var fs = require("fs")
var path = require("path")

var OUT = path.join(__dirname, "..", "data", "hadith")
var FAWAZAHMED0 = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/"
// Pinned to a specific commit for reproducible builds (fetched via
// `git ls-remote https://github.com/AhmedBaset/hadith-json.git HEAD`).
var AHMEDBASET = "https://cdn.jsdelivr.net/gh/AhmedBaset/hadith-json@70b83d6d21995bb32f8d7271cd75501be5a922a7/db/by_book/"

// Download source per collection id. `edition` is the fawazahmed0 edition id
// (null when the collection is only available from AhmedBaset); `ahmedbaset`
// is the AhmedBaset by_book path, the sole source for the supplementary
// collections. The display name comes from Model.COLLECTIONS (single source of
// truth) so the collection picker and the bundled JSON can never diverge.
var SOURCES = {
  bukhari:  { edition: "bukhari",  ahmedbaset: "the_9_books/bukhari.json" },
  muslim:   { edition: "muslim",   ahmedbaset: "the_9_books/muslim.json" },
  tirmidhi: { edition: "tirmidhi", ahmedbaset: "the_9_books/tirmidhi.json" },
  abudawud: { edition: "abudawud", ahmedbaset: "the_9_books/abudawud.json" },
  nasai:    { edition: "nasai",    ahmedbaset: "the_9_books/nasai.json" },
  ibnmajah: { edition: "ibnmajah", ahmedbaset: "the_9_books/ibnmajah.json" },
  malik:    { edition: "malik",    ahmedbaset: "the_9_books/malik.json" },
  ahmad:    { edition: null,       ahmedbaset: "the_9_books/ahmed.json" },
  darimi:   { edition: null,       ahmedbaset: "the_9_books/darimi.json" },
  nawawi:   { edition: null,       ahmedbaset: "other_books/riyad_assalihin.json" },
  adab:     { edition: null,       ahmedbaset: "other_books/aladab_almufrad.json" },
  shamail:  { edition: null,       ahmedbaset: "other_books/shamail_muhammadiyah.json" },
  bulugh:   { edition: null,       ahmedbaset: "other_books/bulugh_almaram.json" },
  mishkat:  { edition: null,       ahmedbaset: "other_books/mishkat_almasabih.json" },
  qudsi:    { edition: "qudsi",    ahmedbaset: "forties/qudsi40.json" },
  dehlawi:  { edition: "dehlawi",  ahmedbaset: "forties/shahwaliullah40.json" }
}

var COLLECTIONS = Model.COLLECTIONS.map(function (c) {
  var s = SOURCES[c.id]
  return { id: c.id, name: c.name, edition: s.edition, ahmedbaset: s.ahmedbaset }
})

// --- build-time edition parse (moved out of Model.js) ------------------------
//
// These helpers run only at build time (this script), never in the plugin
// at runtime, so they live here rather than in Model.js. parseEdition reuses
// Model.collectionName (the only hadith piece shared with the runtime tab);
// chapter lookup is local to this tool, and the text collapse and grade
// extraction are build-only.

function cleanText(raw) {
  return String(raw || "").replace(/\s+/g, " ").trim()
}

// Extracts a human-readable grade string from a hadith record's `grades`
// array. Each entry may name its grading source (g.name) and the grade itself
// (g.grade); both are folded into the label. The two canonical Sahih
// collections ship with empty `grades` arrays, so they default to "Sahih"
// rather than showing a dead badge.
function gradeFrom(record, collection) {
  var grades = record && Array.isArray(record.grades) ? record.grades : []
  var labels = grades.map(function (g) { return String((g && (g.grade || g.name)) || "").trim() }).filter(Boolean)
  if (labels.length === 0 && (collection === "bukhari" || collection === "muslim")) return "Sahih"
  return labels.join("; ")
}

// Resolve which chapter a hadith number belongs to. A collection's hadiths are
// number-sorted, so each number falls in exactly one inclusive [first, last]
// range; a prefatory note outside every range maps to "".
function chapterForHadith(chapters, hadithNumber) {
  for (var i = 0; i < chapters.length; i++) {
    if (hadithNumber >= chapters[i].first && hadithNumber <= chapters[i].last) {
      return { chapterIndex: i, book: chapters[i].name }
    }
  }
  return { chapterIndex: -1, book: "" }
}

// Parses two full-edition responses (English + Arabic) into a browsable
// edition object: { name, chapters, hadiths }.
//
// chapters is [{ name, book, first, last, startIndex }] derived from
// metadata.sections / metadata.section_details, keyed by book number. The empty
// intro entry some editions ship (section "0" with a 0–0 range) is skipped,
// but a section that is merely numbered 0 with a real name/range (Muslim's
// "Introduction", Ibn Majah's "The Book of the Sunnah") is kept. Chapters are
// ordered by first appearance in the hadiths so the chapter picker follows the
// reading order even where book numbering does not.
//
// hadiths is a flat array of { number, text, arabic, grade, book, chapterIndex }
// zipped by index — the eng- and ara- editions ship the same hadiths in the
// same order, so positional pairing is exact. `number` is the API
// hadithnumber, which can be fractional (e.g. 402.2) for sub-hadiths; `book`
// is the resolved chapter name and `chapterIndex` its slot in `chapters` (-1
// for prefatory notes in the unnamed book 0). Chapter membership is decided by
// chapterForHadith's number-range walk (a per-hadith O(C) linear scan;
// onEditionLoaded uses a two-pointer O(H+C) bulk walk at runtime instead).
//
// Returns null when either side fails to parse or is empty.
function parseEdition(englishRaw, arabicRaw, collectionId) {
  try {
    var eng = JSON.parse(String(englishRaw || ""))
    var ara = JSON.parse(String(arabicRaw || ""))
    var engHadiths = eng && Array.isArray(eng.hadiths) ? eng.hadiths : null
    var araHadiths = ara && Array.isArray(ara.hadiths) ? ara.hadiths : null
    if (!engHadiths || !araHadiths || engHadiths.length === 0 || araHadiths.length === 0) return null

    var engMeta = eng.metadata || {}
    var name = String(engMeta.name || "").trim() || Model.collectionName(collectionId)
    var sections = engMeta.sections || engMeta.section || {}
    var details = engMeta.section_details || engMeta.section_detail || {}

    var chapters = []
    var keys = Object.keys(sections).sort(function (a, b) { return parseInt(a, 10) - parseInt(b, 10) })
    for (var k = 0; k < keys.length; k++) {
      var key = keys[k]
      var sname = String(sections[key] || "").trim()
      var d = details[key] || {}
      var first = d.hadithnumber_first
      var last = d.hadithnumber_last
      if (sname === "" && !first && !last) continue
      chapters.push({ name: sname, book: key, first: first || 0, last: last || 0, startIndex: -1 })
    }

    var hadiths = []
    var count = Math.min(engHadiths.length, araHadiths.length)
    for (var i = 0; i < count; i++) {
      var eh = engHadiths[i]
      var ah = araHadiths[i]
      if (!eh || !ah) continue
      var number = typeof eh.hadithnumber === "number" ? eh.hadithnumber : (i + 1)
      var chIdx = chapterForHadith(chapters, number).chapterIndex
      hadiths.push({
        number: number,
        text: cleanText(eh.text),
        arabic: cleanText(ah.text),
        grade: gradeFrom(eh, collectionId),
        book: chIdx >= 0 ? chapters[chIdx].name : "",
        chapterIndex: chIdx
      })
      if (chIdx >= 0 && chapters[chIdx].startIndex < 0) chapters[chIdx].startIndex = i
    }
    if (hadiths.length === 0) return null

    // Keep only chapters that actually appear, ordered by first appearance, and
    // remap each hadith's chapterIndex to its final ordered slot.
    var ordered = []
    for (var c = 0; c < chapters.length; c++) {
      if (chapters[c].startIndex >= 0) ordered.push(chapters[c])
    }
    ordered.sort(function (a, b) { return a.startIndex - b.startIndex })

    var remap = {}
    for (var c2 = 0; c2 < ordered.length; c2++) remap[ordered[c2].book] = c2
    for (var i2 = 0; i2 < hadiths.length; i2++) {
      var chIdx2 = hadiths[i2].chapterIndex
      var rk = chIdx2 >= 0 ? remap[chapters[chIdx2].book] : undefined
      hadiths[i2].chapterIndex = rk === undefined ? -1 : rk
    }

    return { name: name, chapters: ordered, hadiths: hadiths }
  } catch (e) { return null }
}

var MAX_REDIRECTS = 5
var MAX_BODY_BYTES = 100 * 1024 * 1024

function fetch(url, redirects) {
  redirects = redirects || 0
  return new Promise(function (resolve, reject) {
    // jsDelivr redirects http→https, so start with https.
    var u = url.replace(/^http:/, "https:")
    https.get(u, function (res) {
      if (res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 307 || res.statusCode === 308) {
        if (redirects >= MAX_REDIRECTS) return reject(new Error("too many redirects for " + url))
        var loc = res.headers.location
        var host
        try { host = new URL(loc).hostname } catch (e) { return reject(new Error("invalid redirect location for " + url)) }
        // Refuse to follow a redirect off the pinned CDN host (supply-chain /
        // SSRF guard).
        if (host !== "cdn.jsdelivr.net") return reject(new Error("refusing redirect to " + host + " for " + url))
        res.resume()
        return fetch(loc, redirects + 1).then(resolve, reject)
      }
      if (res.statusCode !== 200) {
        res.resume()
        return reject(new Error(url + " returned " + res.statusCode))
      }
      var body = ""
      var bytes = 0
      res.setEncoding("utf8")
      res.on("data", function (chunk) {
        bytes += Buffer.byteLength(chunk, "utf8")
        if (bytes > MAX_BODY_BYTES) {
          res.destroy()
          reject(new Error("response exceeds " + MAX_BODY_BYTES + " bytes for " + url))
          return
        }
        body += chunk
      })
      res.on("end", function () { resolve(body) })
      res.on("error", function (e) { reject(e) })
    }).on("error", reject)
  })
}

// parseEdition output → compact data file. `meta` supplies the curated name;
// chapters collapse to {n,f,l} and hadiths to {n,t,a,g}.
// Note: the fawazahmed0 source does not provide Arabic chapter names.
function compactify(edition, meta) {
  var chapters = edition.chapters.map(function (c) {
    return { n: c.name, f: c.first || 0, l: c.last || 0 }
  })
  var hadiths = edition.hadiths.map(function (h) {
    return { n: h.number, t: h.text, a: h.arabic, g: h.grade }
  }).filter(function (h) { return h.t !== "" || h.a !== "" })
  return {
    name: meta.name,
    chapters: chapters,
    hadiths: hadiths
  }
}

// AhmedBaset book → compact data file. Its english text splits the narrator
// prefix (english.narrator) from the body (english.text), so they are rejoined
// into a single `t`. No grades exist in this source.
function compactifyAhmedBaset(raw, meta) {
  var d = JSON.parse(String(raw || ""))
  if (!d || !Array.isArray(d.chapters) || !Array.isArray(d.hadiths)) throw new Error("unexpected AhmedBaset shape")

  var first = {}
  var last = {}
  var order = []
  for (var i = 0; i < d.hadiths.length; i++) {
    var h = d.hadiths[i]
    var cid = h.chapterId
    if (first[cid] === undefined) { first[cid] = h.idInBook; order.push(cid) }
    last[cid] = h.idInBook
  }

  var byId = {}
  for (var j = 0; j < d.chapters.length; j++) byId[d.chapters[j].id] = d.chapters[j]

  var chapters = []
  for (var o = 0; o < order.length; o++) {
    var ch = byId[order[o]]
    if (!ch) continue
    chapters.push({ n: ch.english || "", a: ch.arabic || "", f: first[order[o]] || 0, l: last[order[o]] || 0 })
  }

  var hadiths = d.hadiths.map(function (hh) {
    var narrator = hh.english && hh.english.narrator ? hh.english.narrator : ""
    var body = hh.english && hh.english.text ? hh.english.text : ""
    return {
      n: hh.idInBook,
      t: (narrator + " " + body).replace(/\s+/g, " ").trim(),
      a: String(hh.arabic || "").replace(/\s+/g, " ").trim(),
      g: ""
    }
  }).filter(function (h) { return h.t !== "" || h.a !== "" })

  return {
    name: meta.name,
    chapters: chapters,
    hadiths: hadiths
  }
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true })

  console.log("Downloading " + COLLECTIONS.length + " collections…\n")

  for (var ci = 0; ci < COLLECTIONS.length; ci++) {
    var c = COLLECTIONS[ci]
    process.stdout.write("[" + (ci + 1) + "/" + COLLECTIONS.length + "] " + c.name + " … ")

    try {
      var compact
      if (c.edition) {
        var engRaw = await fetch(FAWAZAHMED0 + "eng-" + c.edition + ".json")
        var araRaw = await fetch(FAWAZAHMED0 + "ara-" + c.edition + ".json")
        var edition = parseEdition(engRaw, araRaw, c.id)
        if (!edition) throw new Error("parseEdition returned null")

        compact = compactify(edition, c)
      } else {
        var raw = await fetch(AHMEDBASET + c.ahmedbaset)
        compact = compactifyAhmedBaset(raw, c)
      }

      var file = path.join(OUT, c.id + ".json")
      fs.writeFileSync(file, JSON.stringify(compact), "utf8")

      var stats = fs.statSync(file)
      console.log("OK  (" + compact.hadiths.length + " hadiths, " + compact.chapters.length + " chapters, " + (stats.size / 1024).toFixed(1) + " KB)")
    } catch (e) {
      console.log("FAILED — " + (e.message || e))
    }
  }

  // Print a manifest so the plugin knows what's available.
  var sizes = {}
  var files = fs.readdirSync(OUT)
  for (var fi = 0; fi < files.length; fi++) {
    var f = files[fi]
    if (f.endsWith(".json")) {
      sizes[f.replace(".json", "")] = fs.statSync(path.join(OUT, f)).size
    }
  }
  console.log("\nDone. Sizes:")
  for (var si in sizes) console.log("  " + si + ": " + (sizes[si] / 1024).toFixed(1) + " KB")
}

main().catch(function (e) { console.error(e); process.exit(1) })
