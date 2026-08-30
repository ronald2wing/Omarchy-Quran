# AGENTS.md — Omarchy Quran Plugin

- **Repo:** https://github.com/ronald2wing/Omarchy-Quran
- **Tech:** Quickshell QML (Qt 5.15.19) + pure JS (ES5 in QML files; Node for tests/build)
- **Runtime env:** `~/.config/omarchy/plugins/quran/`
- **Offline:** all data bundled, no network at runtime

## Architecture

```
BarWidget.qml           # Entry point (manifest.json). Eager Loader(active:true)→Shell.qml.
                        # Owns the IpcHandler (Shell has manageIpc:false). Injects bar,
                        # anchorItem, hostWidget, and the per-widget Service.qml into Shell.
Shell.qml               # Panel root (~500 lines) — palette, state persistence, routing
                        # (Home/Quran/Hadith). Resolves PrayerService singleton and
                        # forwards it read-only. Instantiated per monitor.
PrayerService.qml       # service-kind singleton — prayer timer, adhan, alert dedup (one per process)
Service.qml             # Per-widget ayah-of-the-day state injected by BarWidget (NOT the singleton)
  components/HomePage.qml   # Ayat of the Day + prayer times + adhan + quick search
  components/QuranPage.qml  # Thin wrapper exposing quranTab alias
  components/QuranTab.qml   # Quran reader + search (dedicated QuranSearchWorker.js)
  components/HadithPage.qml # Thin wrapper exposing hadithTab alias
  components/HadithTab.qml  # Hadith browser — 16 collections
```

Shared JS: `Quran.js`, `Model.js`, `search.js`, `search-flight.js`, `prayer-time.js`, `i18n.js` — imported as namespaces in QML, `require`-d in Node. **ES5 mandatory**: no `const`/`let`/arrow functions/template literals.
Shared UI: `SurfaceCard.qml`, `SuggestionList.qml`, `QuranSearchField.qml`, `QuranReaderHeader.qml`, `QuranResultCard.qml`, `QuranCopyHelper.qml`, `StateFile.qml`, `MedallionBar.qml`, `BasmalaHeader.qml`, `QuranStatusRow.qml`.

## Commands

```bash
# Verify — cheapest first
node --check Quran.js Model.js search.js search-flight.js prayer-time.js i18n.js
node tests/test_quran.js                            # 76 tests

# Deploy to Omarchy
cp Shell.qml BarWidget.qml PrayerService.qml manifest.json ~/.config/omarchy/plugins/quran/
cp components/*.qml components/*.js ~/.config/omarchy/plugins/quran/components/
cp i18n.js Model.js Quran.js search.js prayer-time.js search-flight.js ~/.config/omarchy/plugins/quran/
cp data/quran.json ~/.config/omarchy/plugins/quran/data/
# NOTE: the deployed ~/.config/omarchy/plugins/quran/manifest.json carries
# different author/description fields than the repo copy. If kinds/entryPoints
# change, edit the deployed file in place (or keep both in sync) — don't
# blind-copy over it.

# Restart shell (panels reload)
omarchy restart shell    # or pkill quickshell

# Check for load errors
INST=$(ls -t /run/user/1000/quickshell/by-id/ | head -1)
grep -iE "error|Syntax|unavailable|non-existent" /run/user/1000/quickshell/by-id/$INST/log.log
```

## Qt 5.15 QML Gotchas

1. **`component` keyword is unstable.** Use wrapper Items or inline blocks. Never `component PrayerPill { ... }`.
2. **`property var` reassign does NOT trigger deep binding re-eval.** `obj.name` won't update when `obj` is reassigned. Use scalar props and re-derive in binding expressions.
3. **`onLoadFailed: {}` is a syntax error.** Empty blocks in signal handlers are rejected. Use `onLoadFailed: { /* no-op */ }` or omit.
4. **`TextField` needs `import QtQuick.Controls` plus `import qs.Ui`** for `foreground`/`accent` properties. Without `qs.Ui` these are "non-existent property" errors.
5. **`modelData` is auto-injected by Repeater delegates.** Declare it as `required property var modelData` for explicitness, or reference it directly as bare `modelData` — both work. When using `required property`, Qt 5.15 injects it explicitly; without a declaration, it's still available as an implicit context property.
6. **Bracket notation on JS objects in bindings is unreliable.** Prefer explicit `if/else` chains or scalar properties. `prayerTimes[key]` in the pill Repeater happens to work because `prayerTimes` is a `property var` plain JS object — do not rely on this elsewhere.
7. **`console.log` does NOT appear in the quickshell log.** Use `print()` for all debug output. `console.warn` is also invisible.
8. **`Process` type is `qs.Commons`, NOT `Quickshell.Process`.** The latter module is not installed.
9. **A ListView delegate root with any `required property` disables implicit context injection** (`index`, `model`, role names as bare identifiers). Wrap delegates in a plain `Item` with explicit `required property var modelData` and `required property int index` declarations — these are injected correctly by Qt 5.15. Pass them down to inner components (`rowIndex: index`, `width: ListView.view.width`). Never make `QuranResultCard` the delegate root directly.
10. **Bar widgets run once per monitor.** Omarchy instantiates every bar-widget once per screen (`/usr/share/omarchy/shell/plugins/bar/Bar.qml` `Variants { model: Quickshell.screens }`). With 2 monitors, BarWidget.qml and its eager `Loader → Shell.qml` exist TWICE in one quickshell process, so any timer/side-effect in Shell.qml runs per monitor. The `IpcHandler ... will not be used because another handler is registered for target quran` log warning is the benign symptom of this (the second instance's handler is ignored).

## State architecture

- IpcHandler lives in BarWidget.qml. Shell.qml has `manageIpc: false` — do NOT add a second IpcHandler.
- `Loader { active: true; source: Qt.resolvedUrl("Shell.qml") }` — preloads the panel; `openOnLoad` flag guards the race between click and `onLoaded`.
- User state: `quran-state.json` (surah/ayah/dailyAyat/language/adhanEnabled) and `quran-tab-state.json` (currentPage). Both read by `StateFile` at load, written via `persistState()`/`saveTabState()` debounced at 500ms. Writes go through the `bin/omarchy-statefile` helper for atomic cross-process JSON writes.

## UI language (i18n)

- `root.language` is `"both"` (default)/`"english"`/`"arabic"` — controls verse content visibility and UI chrome language.
- All user-visible strings route through `i18n.js`: `I18n.get(key, language)` for plain strings, `I18n.template(key, language, args)` for parameterized.
- English is the fallback. When `language === "arabic"`, the `"ar"` column renders; otherwise `"en"`.
- Every QML file rendering UI text imports `"../i18n.js" as I18n` and defines local `__`/`_` helpers bound to `root.language`.
- **Never hardcode an English string in UI.** Always use `__("key")` or `_("key", {args})`.

## Prayer time architecture

- **Pipeline lives in `PrayerService.qml`**, an Omarchy `service`-kind singleton (manifest.json `kinds: ["bar-widget","service"]`, `entryPoints.service: "PrayerService.qml"`). Omarchy guarantees one service instance per plugin id per process (`shell.qml` `_services`/`_syncServices`), so alerts fire exactly once regardless of monitor count. The service owns: weather.json `FileView` → `updatePrayerTimes()`, the 10s `prayerTimer`, `alertPrayer()` (notify-send + paplay), `adhanPath`, `adhanStopTimer`, `soundPlaying`, `stopAdhan()`, the `lastNextPrayer`/`notifiedToday` dedup state, and its own `language` property with `__`/`_` i18n helpers for notification text.
- Location: auto-read from `~/.local/state/omarchy/settings/weather.json` (weather plugin). `FileView` lives in PrayerService.qml.
- Computation: `prayer-time.js` `computePrayerTimes()` — pure JS astronomy, MWL angles, Shafi asr default.
- Refresh: `prayerTimer` every 10 seconds. `prayerTick` int increments each cycle to force countdown binding re-eval.
- **Canonical next-prayer resolver:** `Model.nextPrayerName(times, date)` — shared by PrayerService.qml (alert detection) and HomePage.qml (countdown + highlight). Hours are zero-padded for correct lexicographic string comparison. Sunrise is excluded (it is a time marker, not a prayer, and must not trigger a notification). Midnight wraps to fajr.
- **Shell.qml forwards the singleton** read-only: `resolvePrayerService()` via `root.bar.shell.firstPartyServiceFor("quran")`, retried by a 1s Timer until non-null. It exposes `prayerTimes`, `prayerTick` (scalar int — keep for HomePage 10s re-eval), `soundPlaying`, and `stopAdhan()`. Shell OWNS `adhanEnabled` persistence in `quran-state.json` and pushes `adhanEnabled` + `language` to the service via `pushToPrayerService()` (on service resolve and on language change).
- HomePage.qml reads forwarded state via `root.shell.*` and computes `_nextPrayerName`/`_nextPrayerTime` locally with `Model.nextPrayerName()`. It needed zero changes during the service refactor.
- Adhan: optional audio playback (`Quickshell.execDetached(["paplay", ...])`, ~30s OGG) + desktop notification. `adhanStopTimer` (32s) auto-stops playback; `stopAdhan()` pkill's the paplay process.
- **`Service.qml` is NOT the singleton.** It is the existing per-widget ayah-of-the-day state injected by BarWidget.qml — unrelated to PrayerService.qml.

## Search architecture

- Worker threads: `QuranSearchWorker.js` (Quran) and `HadithSearchWorker.js` (Hadith). Both `Qt.include` search.js + data.
- Single-flight dispatch: `search-flight.js` — counter-based bookkeeping for both workers.
- **Hadith corpus pre-seeded** at panel open: `Shell.open()` triggers `hadithPageLoaded = true` via `Qt.callLater`, loading ~13 MB hadith data + seeding the worker corpus in the background before the user navigates to the Hadith tab. A defensive `hadithPageLoaded = true` in `setPage("hadith")` guards the deferred assignment race.
- **enTok precomputed** in `HadithSearchWorker.js`: English text is punctuation-stripped once during seeding, then `_matchesText` reads the precomputed field — zero per-keystroke re-normalization.
- **Query tokenization hoisted** in `searchHadiths()`: tokenized once before the per-hadith loop.
- Result caps: `DEFAULT_MAX_RESULTS` = 114 (114 surahs, 6 iman articles per page).
- 20% scroll threshold triggers lazy pagination (`revealMore`).
- Ref resolution: digit:digit queries flow through `suggestReferences` Path 1 (prefix completion) before `resolveReference`.
- Suggestion `prefixMatches`: exact query match gets +1000 score to always outrank partials.
- Double-search suppressed: `applySuggestion` calls `searchTimer.stop()` before setting `searchField.text`.
- **IDF weights computed at runtime** in the worker via `buildIdf(data)`, called once when the quran data first arrives. `conceptMap` lives in `search.js` as hand-curated source code (33 conceptual-expansion entries, matched at 0.5× IDF weight).

## Refactoring notes

- **5 prayer pills** — Repeater over model `[{key}, ...]`. Colors use palette tokens (`islamicGreen`, `surfaceColor`, `contentForeground`).
- **Gold accent** centralized: Shell.qml `accentColor: "#D4AF37"` (canonical), BarWidget.qml `goldAccent: "#D4AF37"` (pre-load copy). All tints derive from accentColor.
- **SuggestionList.qml** — shared autocomplete dropdown, used by both tabs.
- **No `components/Shell.qml`** — the panel entry is root `Shell.qml`. No `root.results` — hadith results flow through `pendingResults`/`resultModel` only. No `textLower` in Quran `_index` — `searchAyahs` reads only `enTok`/`arabicLower`.
- **`// shared logic — keep in sync`** — `resetSearchState`, `revealMore`, `moveSelection`, `applySuggestion` exist in both tabs with domain-specific field/worker differences. The `shouldRevealMore` helper lives in `search.js`.
- **Arabic normalization centralized** in `Quran.foldArabic()` — no inline regex copies.

## Known to avoid

- Never add `import Quickshell.Process` — module not installed. `Process` and `StdioCollector` come from `Quickshell.Io` (also re-exported by `qs.Commons`).
- Never add `console.log` or `console.warn` in QML — invisible in log. Use `print()`.
- Never duplicate IpcHandler — BarWidget.qml owns it, Shell.qml has `manageIpc: false`.
- Never add timers/notifications/side effects to Shell.qml or BarWidget.qml — they run once per monitor. Put process-wide side effects in `PrayerService.qml` (or another `service`-kind entry).
- Never hardcode a UI string — use `i18n.js` `__`/`_` helpers.
- No catch-all files like `utils.js` or `helpers.qml`.
- Multi-file changes → plan before implementing.

## Data files

- `data/quran.json` — 2.4 MB Quran text (6236 ayahs, 114 surahs).
- `data/hadith/*.json` — 16 collections, compact keys: chapters `{n,f,l,a}`, hadiths `{n,t,a,g}`.
- `assets/` — `adhan.ogg`, `fonts/AmiriQuran.ttf`, `icons/` (UI glyph SVGs: home, book-open, scroll-text, menu).
- `bin/omarchy-statefile` — helper script for atomic cross-process JSON writes.
- `tools/download-hadith.js` — fetches from `https://github.com/AhmedBaset/hadith-json.git` (requires network). Note: its `compactify()` omits the Arabic `a` chapter field; bundled files include it.
