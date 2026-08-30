import QtQuick
import Quickshell
import "Model.js" as Model

// Shared state for the Quran plugin. Shell.qml resolves the day's ayah from
// the bundled translations; this service supplies the date key that changes at
// midnight (so the panel picks a new ayah each day) and carries the resolved
// reference back for the bar tooltip.
Item {
  id: root

  // --- ayah of the day ------------------------------------------------------

  // Date string that rolls over at midnight; Shell.qml picks an ayah when this
  // key changes. Initialized here (rather than only in onDateChanged) so it is
  // available before the first date change fires.
  property string todayKey: ""

  // Written by Shell.qml once it resolves the day's reference; read by
  // BarWidget.qml's tooltip. Empty until the panel has picked one.
  property string todayReference: ""

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.todayKey = Model.isoDate(clock.date)
  }

  Component.onCompleted: {
    root.todayKey = Model.isoDate(clock.date)
  }
}
