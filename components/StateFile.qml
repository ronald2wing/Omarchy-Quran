import QtQuick
import Quickshell.Io

// Shared reader for the panel's JSON state files. All disk access goes
// through bin/omarchy-statefile, which is the security boundary: it performs
// check-and-use in a single open (O_NOFOLLOW on the leaf, O_DIRECTORY|O_NOFOLLOW
// on the parent pinned via /proc/self/fd, fstat + read on that same fd), so no
// separate validation step can race a path swap — a symlinked, oversized, or
// special (FIFO/device) state file is refused in the one open that reads it.
// Writes land in a temp file inside the pinned dir and are atomically renamed
// over the leaf (rename replaces a symlink, never follows it).
//
// restored(parsed) fires after a successful read with the parsed JSON object
// (or null when JSON.parse threw); failed() fires when the helper exited
// nonzero (missing/refused/unreadable file). setText() stages the latest text
// and flushes it through the writer when the previous write finishes, so a
// burst of saves collapses to the trailing value without dropping it.
Item {
  id: root

  required property string path
  required property string helperPath

  signal restored(var parsed)
  signal failed()

  // Latest text awaiting a free writer; cleared by dispatchPendingWrite() the
  // moment it is dispatched so a save arriving mid-write is not lost.
  property string pendingText: ""
  // Text currently being written by writeProc; captured at dispatch so a
  // failed write can re-stage the exact value that was just lost (see
  // writeProc.onExited).
  property string inFlightText: ""

  function reload() {
    if (readProc.running) return
    readProc.command = [root.helperPath, "read", root.path]
    readProc.running = true
  }

  function setText(text) {
    root.pendingText = text
    if (!writeProc.running) root.dispatchPendingWrite()
  }

  function dispatchPendingWrite() {
    if (root.pendingText === "") return
    var t = root.pendingText
    root.pendingText = ""
    root.inFlightText = t
    writeProc.command = [root.helperPath, "write", root.path, t]
    writeProc.running = true
  }

  Process {
    id: readProc
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var parsed = null
        try { parsed = JSON.parse(String(readOut.text || "")) } catch (e) { parsed = null }
        root.restored(parsed)
      } else {
        root.failed()
      }
    }
  }

  Process {
    id: writeProc
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.inFlightText = ""
        if (root.pendingText !== "") root.dispatchPendingWrite()
      } else {
        // Re-stage the value this write just lost so the next setText()/flush
        // retries it; do not retry here (a failing path would loop forever).
        if (root.pendingText === "") root.pendingText = root.inFlightText
        root.inFlightText = ""
        print("StateFile write failed (exit " + exitCode + "): " + root.path)
      }
    }
  }
}
