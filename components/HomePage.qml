// components/HomePage.qml — Mushaf Home landing page — Ayat of the Day, Continue Reading, quick search, prayer times, and adhan controls.
//
// Shows the Ayat of the Day (resolved once by Shell.ensureVerseOfDay and
// injected via `shell.dailyAyat`), a "Continue Reading" button for the last-read
// position (`shell.surah`/`shell.ayah`), and a quick search field that forwards
// to the Quran reader on submit. Clicking the verse copies it; a transient gold
// feedback line confirms. All palette tokens, the parsed quran data, and
// navigation state come from `shell` (the Shell panel).

import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "../Quran.js" as Quran
import "../Model.js" as Model
import "../i18n.js" as I18n

Column {
  id: root
  anchors { left: parent.left; right: parent.right }
  spacing: Style.spacing.md

  function _(key, args) { return I18n.template(key, root.shell.language, args || {}) }
  function __(key) { return I18n.get(key, root.shell.language) }

  // The Shell panel (Shell.qml at plugin root).
  required property QtObject shell

  // Current position and resolved text, updated imperatively by showAyah().
  property int surah: Quran.DEFAULT_SURAH
  property int ayah: Quran.DEFAULT_AYAH
  property string basmala: ""
  property string arabic: ""
  property string english: ""
  readonly property string _localizedRef: root.surah > 0
    ? Quran.formatRefLocalized(root.surah, root.ayah, root.shell.language) : ""

  // Owns clipboard copy + transient "Copied — ..." feedback (shared helper).
  QuranCopyHelper { id: copyHelper }

  // --- prayer helpers: compute next prayer from prayerTimes directly ----------
  // Re-derives next prayer here because Qt 5.15 QML scope propagation from
  // Shell.qml to child components is unreliable. Uses the same canonical
  // Model.nextPrayerName resolver as PrayerService.qml so the logic never diverges.
  readonly property string _nextPrayerName: {
    // Read prayerTick to force binding re-evaluation — not used otherwise.
    var tick = root.shell.prayerTick
    var times = root.shell.prayerTimes
    if (!times || !times.fajr) return ""
    return Model.nextPrayerName(times, new Date())
  }

  readonly property string _nextPrayerTime: {
    var tick = root.shell.prayerTick
    var name = root._nextPrayerName
    var times = root.shell.prayerTimes
    if (!name || !times) return ""
    if (name === "fajr") return times.fajr || ""
    if (name === "dhuhr") return times.dhuhr || ""
    if (name === "asr") return times.asr || ""
    if (name === "maghrib") return times.maghrib || ""
    if (name === "isha") return times.isha || ""
    return ""
  }

  // `tick` is unused in the body: passing prayerTick makes the caller's binding
  // re-evaluate every 10s so the minutes count down even when the next prayer
  // name/time (the only other dependencies) have not changed.
  function countdownText(tick) {
    var name = root._nextPrayerName
    var time = root._nextPrayerTime
    if (name === "" || time === "") return ""
    var label = __("prayer." + name)
    var parts = time.split(":")
    if (parts.length !== 2) return _("prayer.countdown.at", {name: label, time: time})
    var now = new Date()
    var target = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
      parseInt(parts[0], 10), parseInt(parts[1], 10), 0)
    var diff = target.getTime() - now.getTime()
    if (diff <= 0) return _("prayer.countdown.at", {name: label, time: time})
    var h = Math.floor(diff / 3600000)
    var m = Math.floor((diff % 3600000) / 60000)
    return h > 0 ? _("prayer.countdown.in", {name: label, h: String(h), m: String(m)})
                 : _("prayer.countdown.min", {name: label, m: String(m)})
  }

  // --- resolution ------------------------------------------------------------

  function showAyah(surahId, ayahN) {
    var ayahs = Model.ayahsFor(root.shell.quran, surahId)
    var a = (ayahs && ayahs.length >= ayahN) ? ayahs[ayahN - 1] : null
    var ar = a ? (a.ar || "") : ""
    root.surah = surahId
    root.ayah = ayahN
    // The basmala is prepended to ayah 1 of every surah except 1 (where it is
    // the ayah itself) and 9. basmalaFor() already returns "" for those two,
    // and the basmala Text below only renders when basmala !== "", so trust its
    // return value rather than re-deriving the exception.
    root.basmala = Model.basmalaFor(root.shell.quran, surahId)
    root.arabic = Model.arabicFor(root.shell.quran, surahId, ayahN, ar)
    root.english = a ? (a.en || "") : ""
  }

  // Show the day's ayah from Shell's resolved object.
  function applyDaily() {
    var da = root.shell.dailyAyat
    if (!da || !da.reference) return
    root.showAyah(da.reference.surahId, da.reference.ayahN)
  }

  // Up/Down arrows: move to the prev/next ayah with cross-surah wrapping.
  function stepAyah(step) {
    var next = step > 0
      ? Quran.nextAyah(root.surah, root.ayah)
      : Quran.prevAyah(root.surah, root.ayah)
    root.showAyah(next.surahId, next.ayahN)
  }

  function activate() {
    if (root.arabic === "" && root.english === "") return
    var ar = root.basmala !== "" ? root.basmala + " " + root.arabic : root.arabic
    var ref = root._localizedRef
    copyHelper.copy(ar, root.english, root.shell.language, ref,
                    ref + "\n" + __("ayat.source") + "\n\n" + __("copy.footer"))
  }

  // Re-resolve when the quran data or the day's pick arrives on the Shell.
  Connections {
    target: root.shell
    function onQuranChanged() { root.applyDaily() }
    function onDailyAyatChanged() { root.applyDaily() }
  }
  Component.onCompleted: {
    root.applyDaily()
  }

  // --- layout ---------------------------------------------------------------

  // Reference line: the day's pick (or last browsed ayah) in bold gold.
  Text {
    width: parent.width
    text: root._localizedRef !== "" ? root._localizedRef : __("ayat.header")
    textFormat: Text.PlainText
    color: root.shell.accentColor
    font.family: root.shell.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
    wrapMode: Text.WordWrap
  }

  // The verse (optional basmala + Arabic + English) in a surface card.
  SurfaceCard {
    surfaceColor: root.shell.surfaceColor
    borderColor: root.shell.borderColor
    height: verseColumn.implicitHeight + Style.spacing.sm * 2

    Column {
      id: verseColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.lg
      anchors.rightMargin: Style.spacing.lg
      spacing: Style.spacing.xs

      Text {
        width: parent.width
        visible: root.shell.language !== "english" && root.basmala !== ""
        text: root.basmala
        textFormat: Text.PlainText
        color: root.shell.contentForeground
        font.family: root.shell.arabicFontFamily
        font.pixelSize: Style.font.title
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        visible: root.shell.language !== "english"
        text: root.arabic
        textFormat: Text.PlainText
        color: root.shell.accentColor
        font.family: root.shell.arabicFontFamily
        font.pixelSize: Style.font.title
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        visible: root.shell.language !== "arabic"
        text: root.english
        textFormat: Text.PlainText
        color: root.shell.contentForeground
        font.family: root.shell.readerFontFamily
        font.pixelSize: Style.font.heading
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignLeft
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.activate()
    }
  }

  // Copy hint.
  QuranCopyFeedback {
    copyFeedback: copyHelper.feedback
    fontFamily: root.shell.fontFamily
    accentColor: root.shell.accentColor
  }

  // --- Prayer times -----------------------------------------------------------
  // Compact horizontal row of today's prayer times. Each pill shows the name
  // and time; the next upcoming prayer gets a gold accent. Hidden when no
  // location coordinates are available.

  SurfaceCard {
    id: prayerRow
    surfaceColor: root.shell.surfaceColor
    borderColor: root.shell.borderColor
    // Left accent bar — subtle green, not gold, to keep the page hierarchy clean.
    accentBarColor: root.shell.islamicGreen
    height: prayerTimesColumn.visible ? prayerTimesColumn.implicitHeight + Style.spacing.md * 2 : 0
    visible: root.shell.prayerTimes && Object.keys(root.shell.prayerTimes).length > 0

    Column {
      id: prayerTimesColumn
      anchors.centerIn: parent
      spacing: Style.spacing.xs

      Row {
        spacing: Style.spacing.sm
        Text {
          text: __("prayer.header")
          color: root.shell.mutedForeground
          font.family: root.shell.fontFamily
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: root.countdownText(root.shell.prayerTick)
          color: root.shell.accentColor
          font.family: root.shell.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
        // Adhan controls — label, toggle, stop button.
        Text {
          text: __("adhan.sound")
          color: root.shell.mutedForeground
          font.family: root.shell.fontFamily; font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
          height: 18; radius: 4
          anchors.verticalCenter: parent.verticalCenter
          width: adhanLabel.implicitWidth + 10
          color: root.shell.adhanEnabled ? root.shell.accentColor : "transparent"
          border.width: 1
          border.color: root.shell.adhanEnabled ? root.shell.accentColor : root.shell.mutedForeground
          Text {
            id: adhanLabel
            anchors.centerIn: parent
            text: __(root.shell.adhanEnabled ? "adhan.on" : "adhan.off")
            color: root.shell.adhanEnabled ? root.shell.surfaceColor : root.shell.mutedForeground
            font.family: root.shell.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { root.shell.adhanEnabled = !root.shell.adhanEnabled; root.shell.persistState() }
          }
        }
        Rectangle {
          id: adhanStopBtn
          visible: root.shell.adhanEnabled
          height: 18; width: 18; radius: 4
          anchors.verticalCenter: parent.verticalCenter
          border.width: 1
          property bool _flash: false
          readonly property bool _playing: root.shell.soundPlaying
          color: _playing ? (_flash ? root.shell.accentColor : root.shell.surfaceColor) : "transparent"
          border.color: _playing ? (_flash ? root.shell.accentColor : root.shell.mutedForeground)
                                : root.shell.mutedForeground
          Timer {
            running: root.shell.soundPlaying
            repeat: true; interval: 350
            onTriggered: { adhanStopBtn._flash = !adhanStopBtn._flash }
          }
          Text {
            anchors.centerIn: parent
            text: "\u2715"
            color: adhanStopBtn._playing ? (adhanStopBtn._flash ? root.shell.surfaceColor : root.shell.accentColor)
                                        : root.shell.mutedForeground
            font.family: root.shell.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
          MouseArea {
            id: stopBtnMouse
            anchors.fill: parent
            cursorShape: adhanStopBtn._playing ? Qt.PointingHandCursor : Qt.ArrowCursor
            hoverEnabled: true
            onClicked: { if (adhanStopBtn._playing) root.shell.stopAdhan() }
          }
          QQC.ToolTip {
            id: stopTooltip
            visible: stopBtnMouse.containsMouse && !adhanStopBtn._playing
            text: __("adhan.stopHint")
            delay: 300
            x: parent.width + 4
            y: -2
            background: Rectangle {
              color: root.shell.surfaceColor
              border.width: 1
              border.color: root.shell.accentColor
              radius: Style.cornerRadius
            }
            contentItem: Text {
              text: stopTooltip.text
              color: root.shell.contentForeground
              font.family: root.shell.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignLeft
            }
          }
        }
      }

      Row {
        spacing: Style.spacing.sm
        Repeater {
          model: [
            { key: "fajr" },
            { key: "dhuhr" },
            { key: "asr" },
            { key: "maghrib" },
            { key: "isha" }
          ]
          delegate: Rectangle {
            readonly property bool isNext: root._nextPrayerName === modelData.key
            width: Math.max(64, (prayerRow.width - Style.spacing.lg * 2 - Style.spacing.sm * 4) / 5)
            height: 52; radius: Style.space(3)
            color: isNext ? root.shell.islamicGreen : root.shell.surfaceColor
            border.width: Style.space(1)
            border.color: isNext ? root.shell.accentColor : Qt.rgba(1, 1, 1, 0.15)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top; anchors.topMargin: 6
              text: __("prayer." + modelData.key); textFormat: Text.PlainText
              color: root.shell.contentForeground
              font.family: root.shell.fontFamily; font.pixelSize: 12; font.bold: parent.isNext
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom; anchors.bottomMargin: 6
              text: root.shell.prayerTimes[modelData.key] || __("prayer.na"); textFormat: Text.PlainText
              color: parent.isNext ? root.shell.accentColor : root.shell.contentForeground
              font.family: root.shell.fontFamily; font.pixelSize: 14; font.bold: parent.isNext
            }
          }
        }
      }
    }
  }

  // --- Continue Reading ------------------------------------------------------

  SurfaceCard {
    surfaceColor: root.shell.surfaceColor
    borderColor: root.shell.borderColor
    // Left accent bar to distinguish from the search field below.
    accentBarColor: root.shell.accentColor
    height: continueRow.implicitHeight + Style.spacing.md * 2

    Row {
      id: continueRow
      anchors.centerIn: parent
      spacing: Style.spacing.sm

      Text {
        text: "\u25B6"
        color: root.shell.accentColor
        font.family: root.shell.fontFamily
        font.pixelSize: Style.font.body
      }
      Text {
        text: __("ayat.continue") + Quran.formatRefLocalized(root.shell.surah, root.shell.ayah, root.shell.language)
        color: root.shell.contentForeground
        font.family: root.shell.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.shell.setPage("quran")
    }
  }

  // --- Quick search ----------------------------------------------------------

  QuranSearchField {
    id: quickSearch
    width: parent.width
    placeholderText: __("search.quran")
    closeGlyph: "\u2715"
    accentColor: root.shell.accentColor
    contentForeground: root.shell.contentForeground
    mutedForeground: root.shell.mutedForeground
    surfaceColor: root.shell.surfaceColor
    borderColor: root.shell.borderColor
    fontFamily: root.shell.fontFamily
    dimOpacity: root.shell.dimOpacity
    keyCatcher: root.shell.keyCatcher
    onAccepted: {
      root.shell.pendingSearch = quickSearch.text
      root.shell.setPage("quran")
    }
}
}
