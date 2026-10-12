import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "prayer-time.js" as PT
import "i18n.js" as I18n

// Prayer pipeline singleton. The bar instantiates one Shell panel per monitor,
// so anything that must fire once per process (adhan audio + notify-send at
// each prayer time) lives here. Omarchy creates exactly one instance per
// plugin id (`_services` in shell.qml), which is what deduplicates the alerts
// across monitors.
Item {
  id: root

  Component.onCompleted: fallbackTimer.start()

  // UI locale — pushed from Shell.qml; "both" until the panel loads.
  property string language: "both"

  // i18n helpers — resolve notification strings in the active locale.
  function __(key) { return I18n.get(key, root.language) }
  function _(key, args) { return I18n.template(key, root.language, args || {}) }

  // --- prayer times ----------------------------------------------------------
  // Computed from weather.json coordinates. Empty when no location is set.
  property var prayerTimes: ({})
  property string nextPrayerName
  property int prayerTick: 0
  property string dateKey   // YYYY-MM-DD of the last prayer-times computation

  property bool adhanEnabled   // persisted — user opts in
  onAdhanEnabledChanged: { if (!root.adhanEnabled) root.stopAdhan() }

  property bool soundPlaying  // true while adhan audio is active

  readonly property string adhanPath: {
    var p = Model.fileUrlToPath(Qt.resolvedUrl("assets/adhan.ogg"))
    return (typeof p === "string" && p.length > 0) ? p : ""
  }

  Timer {
    id: adhanStopTimer
    interval: 32000   // 30s adhan + 2s grace
    repeat: false
    onTriggered: { root.soundPlaying = false }
  }

  // Previously observed next-prayer name. When it rolls over, the old value is
  // the prayer whose time just arrived and should be alerted.
  property string lastNextPrayer
  property var notifiedToday: ({})

  // --- location --------------------------------------------------------------
  // Priority: weather (from weather.json FileView) > persisted (Shell pushes
  // after state restore) > tz probe (offline fallback).
  property real prayerLatitude
  property real prayerLongitude
  property string _source: ""  // "weather" | "persisted" | "tz"

  function hasLocation() {
    return root.prayerLatitude !== 0.0 || root.prayerLongitude !== 0.0
  }

  function setLocation(lat, lon, source) {
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return
    // Weather is authoritative — never downgrade.
    if (root._source === "weather" && source !== "weather") return
    root.prayerLatitude = lat
    root.prayerLongitude = lon
    root._source = source
    root.updatePrayerTimes()
    root.locationResolved()
  }

  // Emitted when coordinates resolve — Shell persists them so a restart is
  // instant instead of re-probing.
  signal locationResolved()

  // Offline timezone -> coordinate fallback. Resolve the system timezone name,
  // look it up in the local zone tab, and parse the ISO 6709 coordinate via
  // the pure-JS parser (no awk needed).
  function resolveCoordinates() {
    if (root.hasLocation()) return
    tzProbe.running = true
  }

  // Delay: give Shell time to push persisted coords (weather.json FileView
  // fires synchronously if the file exists; the 1.5s covers the async state-
  // file read path before the tz probe runs).
  Timer {
    id: fallbackTimer
    interval: 1500
    repeat: false
    onTriggered: root.resolveCoordinates()
  }

  Process {
    id: tzProbe
    // Emit: line 1 = timezone name, then zone.tab content on stdout.
    command: ["timeout", "5", "bash", "-c",
      "tz=\"\"\n" +
      "if [ -e /etc/localtime ]; then\n" +
      "  link=$(readlink -f /etc/localtime 2>/dev/null)\n" +
      "  case \"$link\" in */zoneinfo/*) tz=${link#*/zoneinfo/} ;; esac\n" +
      "fi\n" +
      "if [ -z \"$tz\" ] && [ -r /etc/timezone ]; then\n" +
      "  tz=$(head -n1 /etc/timezone 2>/dev/null)\n" +
      "fi\n" +
      "if [ -z \"$tz\" ] && command -v timedatectl >/dev/null 2>&1; then\n" +
      "  tz=$(timedatectl show --property=Timezone --value 2>/dev/null)\n" +
      "fi\n" +
      "case \"$tz\" in \"\"|UTC|Etc/*) exit 0 ;; esac\n" +
      "echo \"$tz\"\n" +
      "for tab in /usr/share/zoneinfo/zone1970.tab /usr/share/zoneinfo/zone.tab /etc/zoneinfo/zone1970.tab /etc/zoneinfo/zone.tab; do\n" +
      "  if [ -r \"$tab\" ]; then cat \"$tab\"; break; fi\n" +
      "done\n"
    ]
    stdout: StdioCollector { id: tzStdout; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) return
      var text = String(tzStdout.text || "")
      var newline = text.indexOf("\n")
      if (newline < 1) return
      var tz = text.substring(0, newline)
      var tab = text.substring(newline + 1)
      var coords = PT.resolveTimezoneCoordinate(tab, tz)
      if (!coords) return
      root.setLocation(coords.latitude, coords.longitude, "tz")
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    printErrors: false
    watchChanges: true
    onFileChanged: this.reload()
    onLoaded: {
      try {
        var w = JSON.parse(text())
        if (typeof w.latitude === "number" && typeof w.longitude === "number"
            && Number.isFinite(w.latitude) && Number.isFinite(w.longitude)) {
          root.setLocation(w.latitude, w.longitude, "weather")
          return
        }
      } catch (e) { /* drop through to fallback */ }
      root.resolveCoordinates()
    }
    // File absent — Omarchy's weather "auto" mode deletes it.
    onLoadFailed: { root.resolveCoordinates() }
  }

  function updatePrayerTimes() {
    if (!root.hasLocation()) return
    try {
      var today = new Date()
      var times = PT.computePrayerTimes(today, root.prayerLatitude, root.prayerLongitude)
      root.prayerTimes = times
      var dateStr = Model.isoDate(today)
      if (root.dateKey !== dateStr) {
        root.dateKey = dateStr
        root.notifiedToday = {}
        root.lastNextPrayer = ""
      }
      // Canonical resolver shared with HomePage.qml; sunrise is excluded.
      root.nextPrayerName = Model.nextPrayerName(times, today)
      root.prayerTick++  // Scalar tick forces HomePage countdown bindings to re-evaluate every cycle.
    } catch (e) {
      // Prayer computation is best-effort; a malformed time must not crash the service.
    }
  }

  // Refresh every 10 seconds — keeps the countdown current and ensures prayer-
  // time alerts fire within seconds of the actual prayer time.
  Timer {
    id: prayerTimer
    interval: 10000
    repeat: true
    running: root.hasLocation()
    onTriggered: {
      root.updatePrayerTimes()
      // Check for prayer-time alerts
      var cur = root.nextPrayerName
      if (cur === "" || root.lastNextPrayer === "") {
        root.lastNextPrayer = cur
        return
      }
      // Alert the prayer that just ended: when the next-prayer name rolls over, the previous value is the prayer whose time has arrived.
      if (root.lastNextPrayer !== cur) {
        if (!root.notifiedToday[root.lastNextPrayer]) {
          root.notifiedToday[root.lastNextPrayer] = true
          root.alertPrayer(root.lastNextPrayer)
        }
        root.lastNextPrayer = cur
      }
    }
  }

  function alertPrayer(name) {
    var nameAr = __("prayer." + name)
    if (root.adhanEnabled && root.adhanPath !== "") {
      Quickshell.execDetached(["paplay", root.adhanPath])
      root.soundPlaying = true
      adhanStopTimer.restart()
    }
    var body = _("notify.body", {name: nameAr})
    if (root.adhanEnabled) body += " — " + _("notify.stopHint", {})
    Quickshell.execDetached([
      "notify-send",
      "--urgency=normal",
      _("notify.title", {name: nameAr}),
      body,
      "--icon=audio-volume-high"
    ])
  }

  function stopAdhan() {
    Quickshell.execDetached(["pkill", "-f", "paplay.*adhan"])
    root.soundPlaying = false
  }
}
