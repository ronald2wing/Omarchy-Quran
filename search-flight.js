// search-flight.js — shared single-flight WorkerScript dispatch for the Quran
// and Hadith tabs.
//
// Both tabs run searches off the UI thread through a WorkerScript and share the
// same single-flight protocol: at most one query is in the worker at a time, and
// the trailing query typed while one is in flight is queued and dispatched once
// the reply lands — never dropped. Each tab keeps its own message construction
// and result handling (they differ), but the bookkeeping — the in-flight
// counter, the pending-query queue, the decrement-on-reply, and the stale-reply
// guard — is identical and lives here.
//
// The state is a plain mutable object ({ inFlight, pending }) so the
// functions can update it in place: QML copies ints/strings by value, so a bare
// `int inFlight` property could never be mutated through a JS function.
// Loaded via `import "../search-flight.js" as SearchFlight` in the tab files;
// it has no Node exports and is only ever used from QML.

// Fresh flight state.
function makeState() {
  return { inFlight: 0, pending: "" }
}

// Queue `query` and report whether the caller should dispatch immediately.
// Trailing-query-wins: a later enqueue overwrites a queued (not-yet-sent) query
// so only the newest is ever sent.
function enqueue(state, query) {
  state.pending = query
  return state.inFlight === 0
}

// Pop and return the queued query ("" when nothing is pending), mirroring the
// head of each tab's flushSearchPending().
function takePending(state) {
  var query = state.pending
  state.pending = ""
  return query
}

// Record a sent message: increment the in-flight count.
function markSent(state) {
  state.inFlight++
}

// Acknowledge a worker reply. Called before the stale guard so the count can
// never wedge (the worker always replies exactly once per dispatch), then
// reports whether the reply belongs to the query the tab is now showing.
function ack(state, replyQuery, currentQuery) {
  if (state.inFlight > 0) state.inFlight--
  return replyQuery === currentQuery
}

// Drop any queued-but-unsent query (search cleared while a query was pending).
function clear(state) {
  state.pending = ""
}
