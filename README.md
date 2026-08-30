# Omarchy Quran Plugin

An offline Quran reader for the [Omarchy](https://omarchy.org) desktop shell. Quran and Hadith search, prayer times with adhan, bilingual UI — no API keys, no network calls.

**Repository:** https://github.com/ronald2wing/Omarchy-Quran

## Features

- **Ayat of the Day** — deterministic daily verse, Arabic + English, gold-on-green palette
- **Quran reader** — all 114 surahs (6,236 ayahs); keyboard navigation, copy with attribution
- **Offline search** — IDF-weighted relevance scoring, reference lookup ("2:255"), surah-name completion, proximity mode
- **Hadith browser** — Bukhari, Muslim, Tirmidhi, Abu Dawud, Nasai, Ibn Majah, Malik, Ahmad, Darimi, Nawawi, Adab al-Mufrad, Shamail, Bulugh al-Maram, Mishkat, Qudsi, Dehlawi
- **Prayer times** — astronomical calculation (MWL method), countdown with next-prayer highlight, adhan audio, desktop notifications
- **Bilingual UI** — Arabic/English toggle localizes all chrome, labels, and notifications
- **Persistent state** — last-read position, language, daily ayah, adhan toggle

## Install

```bash
omarchy plugin add https://github.com/ronald2wing/Omarchy-Quran --enable
```

Prayer-time coordinates are auto-read from the weather plugin (`~/.local/state/omarchy/settings/weather.json`).

## Build (optional)

Pre-built data ships in the repo. Rebuild hadith data only when upstream sources change.

```bash
node tools/download-hadith.js      # fetch hadith collections (needs network)
```

## Test

```bash
node tests/test_quran.js           # 76 tests
```

## Project structure

```
Shell.qml              # Panel root — palette, state, routing (per monitor)
BarWidget.qml          # Entry point + IPC handler, preloads Shell
PrayerService.qml      # Service singleton — prayer timer, adhan, alert dedup
Service.qml            # Per-widget ayah-of-the-day state
Quran.js               # Surah metadata, reference parsing, Arabic normalization
Model.js               # Daily ayah, hadith metadata, next-prayer resolver
search.js              # Search engine (Quran + Hadith), runtime IDF, concept map
search-flight.js       # Worker single-flight dispatch
prayer-time.js         # Astronomical prayer times (MWL)
i18n.js                # UI translations (Arabic/English)
components/            # QML pages, tabs, shared widgets
  HomePage.qml         #     Ayat of the Day, prayer times, adhan, quick search
  QuranTab.qml         #     Quran reader + search
  HadithTab.qml        #     Hadith browser (16 collections)
  QuranPage.qml        #     Thin wrapper → quranTab
  HadithPage.qml       #     Thin wrapper → hadithTab
  BasmalaHeader.qml    #     Bismillah + language toggle
  MedallionBar.qml     #     Tab navigation (Ayat/Quran/Hadith)
  QuranCopyFeedback.qml#     Transient "Copied" overlay
  QuranCopyHelper.qml  #     Clipboard copy with attribution
  QuranNavButton.qml   #     Gold icon button
  QuranPositionBar.qml #     Position track (Quran/Hadith)
  QuranReaderHeader.qml#     Surah header + position bar
  QuranResultCard.qml  #     Result row (Quran + Hadith)
  QuranSearchField.qml #     Search input with clear button
  QuranStatusRow.qml   #     Keyboard hints + result count
  QuranTooltip.qml     #     Hover tooltip
  SuggestionList.qml   #     Autocomplete dropdown
  SurfaceCard.qml      #     Card surface
  StateFile.qml        #     Debounced state persistence
  HadithSearchWorker.js#     Off-thread hadith search
  QuranSearchWorker.js #     Off-thread Quran search
data/                  # quran.json, hadith/*.json (16 collections)
assets/                # adhan.ogg, fonts (AmiriQuran.ttf), icons (SVG)
bin/                   # omarchy-statefile (state write helper)
tools/                 # download-hadith.js
tests/                 # Node unit tests
```

## License

MIT — see [manifest.json](manifest.json).
