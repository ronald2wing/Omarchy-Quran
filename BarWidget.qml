import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "i18n.js" as I18n

BarWidget {
  id: root
  moduleName: "quran"

  // UI locale — mirrors the panel (Shell.qml) so the tooltip fallback and IPC
  // status localize. "both" (bilingual) until the panel finishes loading.
  readonly property string language: panelLoader.item ? panelLoader.item.language : "both"

  function __(key) { return I18n.get(key, root.language) }

  Service {
    id: service
  }

  // Today's reference once resolved, else the tab label — shared by the IPC
  // status line and the button tooltip fallback.
  readonly property string statusLabel: service.todayReference !== "" ? service.todayReference : __("tab.quran")

  // Prayer-service singleton — resolved by retry timer (same pattern as
  // Shell.qml). Qt 5.15 does not deeply re-eval bindings through C++-backed
  // properties, so firstPartyServiceFor may return null on the first tick.
  property var prayerService: null

  function resolvePrayerService() {
    if (root.prayerService) return true
    if (!root.bar || !root.bar.shell) return false
    var svc = root.bar.shell.firstPartyServiceFor("quran")
    if (svc) root.prayerService = svc
    return !!svc
  }

  // Combine next prayer time + today's ayah in the tooltip.
  readonly property string tooltipLabel: {
    var parts = []
    var svc = root.prayerService
    if (svc) {
      var times = svc.prayerTimes
      var tick = svc.prayerTick  // force binding re-eval every 10s
      var name = svc.nextPrayerName
      if (name && times[name]) parts.push(__("tooltip.prayer") + " " + __("prayer." + name) + " " + times[name])
    }
    if (service.todayReference !== "") parts.push(__("tooltip.ayah") + " " + service.todayReference)
    if (parts.length === 0) parts.push(__("tab.quran"))
    return parts.join("\n")
  }

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Islamic gold — must match Shell.qml accentColor. Kept here because
  // BarWidget instantiates before the panel Loader resolves Shell.qml.
  readonly property color goldAccent: "#D4AF37"

  // Guards the brief pre-load race: if the user clicks before onLoaded fires,
  // the panel opens itself once the Loader finishes instantiating it.
  property bool openOnLoad: false

  function open() {
    if (!panelLoader.item) {
      root.openOnLoad = true
      return
    }
    panelLoader.item.open()
  }

  function close() {
    root.openOnLoad = false
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (!panelLoader.item) return root.open()
    panelLoader.item.toggle()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = service
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: {
    root.injectPanel()
    Qt.callLater(function() {
      if (!root.resolvePrayerService()) prayerServiceRetry.start()
    })
  }

  Timer {
    id: prayerServiceRetry
    interval: 1000
    repeat: true
    running: false
    onTriggered: { if (root.resolvePrayerService()) stop() }
  }

  Loader {
    id: panelLoader
    // Preload the panel so the deferred ~13MB JSON parse happens in the
    // background instead of stalling on first click.
    active: true
    source: Qt.resolvedUrl("Shell.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
      if (root.openOnLoad) {
        root.openOnLoad = false
        panelLoader.item.open()
      }
    }
  }

  IpcHandler {
    target: "quran"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function togglePanel(): void { root.togglePanel() }
    function status(): string {
      return root.statusLabel
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltipLabel
    // Islamic gold — keep in sync with Shell.qml accentColor
    foreground: root.goldAccent
    iconComponent: Component {
      Text {
        anchors.centerIn: parent
        // fa-star-and-crescent. The FA6 codepoint (U+F699) is absent from the
        // bar's Nerd Font, so use the PUA alias (U+EEE1) which renders. The
        // Image/SVG variant never rendered inside BarIconButton's Loader, so a
        // glyph is used here like the bible widget's book.
        text: "\uEEE1"
        color: root.goldAccent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
