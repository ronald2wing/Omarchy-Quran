// components/QuranCopyHelper.qml — shared clipboard copy + feedback timer.
//
// Owns the "copy to clipboard + transient 'Copied — ...' feedback" flow that
// HomePage, QuranTab, and HadithTab each used to duplicate inline. Each tab
// declares one of these at the root of its component tree and calls copy() from
// its activate/copy function, so the payload assembly, clipboard write, feedback
// string, and 2s auto-clear live in one place instead of three near-identical
// copies.

import QtQuick
import Quickshell
import "../i18n.js" as I18n

QtObject {
  id: root

  // Transient "Copied — ..." text shown by the owning tab's QuranCopyFeedback;
  // cleared 2s after each copy.
  property string feedback: ""

  property Timer timer: Timer {
    interval: 2000
    repeat: false
    onTriggered: root.feedback = ""
  }

  // Copies arabic + english (plus an optional footer — the reference, source
  // attribution, or grade) to the clipboard, then shows feedback for 2s.
  //   language: "both" | "english" | "arabic" — which of the two to include
  //   referenceLabel: human-readable reference shown in the feedback text
  //   footer: optional trailing text appended after a blank line
  function copy(arabic, english, language, referenceLabel, footer) {
    var parts = []
    if (language === "both" || language === "arabic") parts.push(arabic)
    if (language === "both" || language === "english") parts.push(english)
    var text = parts.filter(function (p) { return p !== "" }).join("\n\n")
    if (footer) {
      if (text) text += "\n\n" + footer
      else text = footer
    }
    if (!text) return
    Quickshell.clipboardText = text
    feedback = I18n.template("copy.feedback", language, {label: referenceLabel})
    timer.restart()
  }
}
