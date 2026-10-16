// components/QuranClipboardReader.qml — bounded async clipboard reader.
//
// Runs a single out-of-process pipeline that reads plain-text clipboard content
// through wl-paste, capped at 4096 bytes and a one-second deadline, with UTF-8
// validation via iconv.  This replaces Qt's native clipboard-change read
// (dataChanged → canPasteChanged → mimeData()->text()) which would let a
// foreign Wayland clipboard owner stream unbounded data into the shell.
//
// API:
//   request(field, usePrimary) — starts a bounded read; calls back into field.finishPaste()
//   cancel()                  — aborts the running read
//
// Each paste transfer is one atomic operation: the pipeline is killed by
// timeout (including process-group descendents) on any timeout, exit > 0,
// or output > 4096 bytes.
import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property bool busy: false
  property var targetField: null

  // Watchdog for a missing binary: a failed start emits runningChanged (not
  // exited), so onExited never fires and busy would stay true forever.  This
  // timer resets the reader if no exit arrives within 1500ms — longer than the
  // pipeline's 1s deadline, so a legitimate slow read near the boundary is not
  // falsely reset.
  property Timer watchdog: Timer {
    interval: 1500
    repeat: false
    onTriggered: {
      if (!root.busy) return
      root.busy = false
      var field = root.targetField
      root.targetField = null
      // Exit code 1 (non-zero) + normal exit leaves the field unchanged in
      // finishPaste, so the field recovers instead of staying busy.
      if (field && typeof field.finishPaste === "function") {
        field.finishPaste("", 1, 1)
      }
    }
  }

  // QtObject has no default property, so the Process must be bound to an
  // explicit property — not placed as a direct child.
  readonly property Process pasteProc: Process {
    stdout: StdioCollector { id: stdoutCollector; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      root.watchdog.stop()
      var oldField = root.targetField
      // Reset state BEFORE calling back so a new request() from inside
      // finishPaste does not hit the busy guard.
      root.busy = false
      root.targetField = null

      if (!oldField || typeof oldField.finishPaste !== "function") return

      // StdioCollector.text holds only the current run's output — the
      // collector overwrites (not accumulates) per run.  waitForEnd: true
      // guarantees text is the final run's data at onExited.
      var out = String(stdoutCollector.text || "")

      // head -c 4097 caps the run at 4097 bytes; for ASCII that is 4097 chars,
      // so a char count over 4096 means the 4096-byte content limit was
      // exceeded.  Reject here so the field never needs to know the reader's
      // internal byte cap.  (Oversized multibyte input cut mid-codepoint is
      // rejected earlier by iconv's non-zero exit.)
      if (out.length > 4096) {
        oldField.finishPaste("", 1, 1)
        return
      }

      // exitStatus === 0 is QProcess::NormalExit; non-zero means crash or
      // signal.  Let finishPaste handle both exitCode and exitStatus.
      oldField.finishPaste(out, exitCode, exitStatus)
    }
  }

  function request(field, usePrimary) {
    // A request arriving during an in-flight read cancels and restarts it, so
    // the newer paste wins instead of being silently lost.
    if (root.busy) root.cancel()

    root.busy = true
    root.targetField = field
    root.watchdog.restart()

    // Build the bounded pipeline:
    //   timeout   — enforces 1s deadline, kills whole process group (+ wl-paste child)
    //   wl-paste  — reads clipboard (--primary for middle-click)
    //   head -c   — reads 4097 bytes (4 KiB + 1 to detect overflow)
    //   iconv     — passes through valid UTF-8, exits non-zero on invalid bytes
    pasteProc.command = [
      "timeout", "--signal=TERM", "--kill-after=0.2s", "1s",
      "bash", "-c",
      "wl-paste --no-newline" + (usePrimary ? " --primary" : "")
        + " --type text/plain | head -c 4097 | iconv -f UTF-8 -t UTF-8"
    ]
    pasteProc.running = true
  }

  function cancel() {
    pasteProc.running = false
    root.watchdog.stop()
    root.busy = false
    root.targetField = null
  }

  Component.onDestruction: root.cancel()
}