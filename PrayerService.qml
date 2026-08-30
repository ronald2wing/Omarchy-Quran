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

  // --- prayer-time coordinates from the weather plugin -----------------------
  // The weather plugin stores {name, latitude, longitude} in weather.json.
  // Reading it here means the user never configures location twice.
  property real prayerLatitude
  property real prayerLongitude

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    printErrors: false
    watchChanges: true
    onFileChanged: this.reload()
    onLoaded: {
      try {
        var w = JSON.parse(text())
        if (typeof w.latitude === "number" && typeof w.longitude === "number") {
          root.prayerLatitude = w.latitude
          root.prayerLongitude = w.longitude
          root.updatePrayerTimes()
        }
      } catch (e) {
        // weather.json may be absent or malformed; fall back to no location.
      }
    }
  }

  function updatePrayerTimes() {
    if (root.prayerLatitude === 0.0 && root.prayerLongitude === 0.0) return
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
    running: root.prayerLatitude !== 0.0 && root.prayerLongitude !== 0.0
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
