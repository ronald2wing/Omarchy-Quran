// prayer-time.js — Pure-JS offline prayer time calculation.
// No network calls, no API keys, no dependencies. The algorithm is standard
// astronomical computation (sun position from latitude/longitude/date) using
// the Muslim World League convention.
//
// Usage:
//   var times = computePrayerTimes(new Date(), latitude, longitude)
//   // → { fajr: "05:23", dhuhr: "12:45", asr: "16:10", maghrib: "18:55", isha: "20:15" }
//
// Platforms: QML (Qt.include / import), WorkerScript, Node tests.
// ES5-compatible (no const/let/arrow-functions in core; Node wrapper at bottom).

// ---- math helpers ---------------------------------------------------------

function _rad(d) { return d * Math.PI / 180 }
function _deg(r) { return r * 180 / Math.PI }
function _mod(x, y) { return ((x % y) + y) % y }
function _pad(n) { return n < 10 ? "0" + n : String(n) }

// ---- Julian date -----------------------------------------------------------
// Returns Julian date for a given JS Date object.
function _julianDate(date) {
  var year = date.getFullYear()
  var month = date.getMonth() + 1
  var day = date.getDate()
  if (month <= 2) { year -= 1; month += 12 }
  var A = Math.floor(year / 100)
  var B = 2 - A + Math.floor(A / 4)
  return Math.floor(365.25 * (year + 4716))
       + Math.floor(30.6001 * (month + 1))
       + day + B - 1524.5
}

// ---- sun position ----------------------------------------------------------

// Calculate sun declination and equation of time for a given Julian date.
// Returns { declination: degrees, eqTime: minutes }
function _sunPosition(jd) {
  var D = jd - 2451545.0  // days since J2000.0
  var g = _mod(357.529 + 0.98560028 * D, 360)
  var q = _mod(280.459 + 0.98564736 * D, 360)
  var L = _mod(q + 1.915 * Math.sin(_rad(g)) + 0.020 * Math.sin(_rad(2 * g)), 360)
  var epsilon = 23.439 - 0.00000036 * D
  var declination = _deg(Math.asin(Math.sin(_rad(epsilon)) * Math.sin(_rad(L))))
  var eqt = 4 * _deg(
    Math.tan(_rad(epsilon / 2)) * Math.tan(_rad(epsilon / 2)) * Math.sin(2 * _rad(q))
    - 2 * 0.0167 * Math.sin(_rad(g))
    + 4 * 0.0167 * Math.tan(_rad(epsilon / 2)) * Math.tan(_rad(epsilon / 2))
        * Math.sin(_rad(g)) * Math.cos(2 * _rad(q))
    - 0.5 * Math.tan(_rad(epsilon / 2)) * Math.tan(_rad(epsilon / 2))
        * Math.tan(_rad(epsilon / 2)) * Math.tan(_rad(epsilon / 2))
        * Math.sin(4 * _rad(q))
    - 1.25 * 0.0167 * 0.0167 * Math.sin(2 * _rad(g))
  )
  return { declination: declination, eqTime: eqt }
}

// ---- prayer times ----------------------------------------------------------

// Default sun angles (Muslim World League).
// Override by passing a different `angles` object.
var MWL_ANGLES = {
  fajr: -18,
  isha: -17
}
// Asr method: 1 = Shafi (shadow = 1x), 2 = Hanafi (shadow = 2x)
var SHAFI = 1
var HANAFI = 2

// Compute prayer times for a given date, latitude, and longitude.
// Returns { fajr, sunrise, dhuhr, asr, maghrib, isha } as "HH:MM" strings.
// Optional `options`:
//   - angles: { fajr: -18, isha: -17 }  (default MWL)
//   - asrMethod: 1 (Shafi) or 2 (Hanafi)  (default Shafi)
//   - timezone:  override auto-detected offset in hours (e.g. 3)
function computePrayerTimes(date, latitude, longitude, options) {
  var opts = options || {}
  var angles = opts.angles || MWL_ANGLES
  var asrMethod = opts.asrMethod || SHAFI
  var tzOffset = typeof opts.timezone === "number"
    ? opts.timezone
    : -date.getTimezoneOffset() / 60

  var jd = _julianDate(date)
  var pos = _sunPosition(jd)
  var declination = pos.declination
  var eqTime = pos.eqTime

  // Dhuhr = solar noon
  var dhuhr = 12 + tzOffset - longitude / 15 - eqTime / 60

  // Calculate hour angle for a given sun altitude
  function hourAngle(altitude) {
    return _deg(Math.acos(
      (Math.sin(_rad(altitude)) - Math.sin(_rad(latitude)) * Math.sin(_rad(declination)))
      / (Math.cos(_rad(latitude)) * Math.cos(_rad(declination)))
    ))
  }

  // Asr shadow factor: Shafi = arccot(1 + tan(|lat-decl|)), Hanafi = arccot(2 + ...)
  function asrAngle() {
    var shadowLength = asrMethod === HANAFI ? 2 : 1
    return _deg(Math.atan(1 / (shadowLength + Math.tan(_rad(Math.abs(latitude - declination))))))
  }

  var fajrAngle = hourAngle(angles.fajr)
  var sunriseAngle = hourAngle(-0.833)  // sun upper limb touches horizon
  var asrAlt = asrAngle()
  var asrHa = hourAngle(asrAlt)
  var maghribAngle = hourAngle(-0.833)
  var ishaAngle = hourAngle(angles.isha)

  // Convert hour angles to times
  var fajr = dhuhr - fajrAngle / 15
  var sunrise = dhuhr - sunriseAngle / 15
  var asr = dhuhr + asrHa / 15
  var maghrib = dhuhr + maghribAngle / 15
  var isha = dhuhr + ishaAngle / 15

  // Format to HH:MM
  function fmt(hours) {
    var h = Math.floor(_mod(hours, 24))
    var m = Math.floor(_mod(hours * 60, 60))
    return _pad(h) + ":" + _pad(m)
  }

  return {
    fajr: fmt(fajr),
    sunrise: fmt(sunrise),
    dhuhr: fmt(dhuhr),
    asr: fmt(asr),
    maghrib: fmt(maghrib),
    isha: fmt(isha)
  }
}

// ---- Node / module exports ------------------------------------------------
// QML's JS engine has no `module`; the guard skips the block under QML import
// while Node require() sees module.exports. `typeof` never throws for an
// undeclared identifier, so no try/catch is needed.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    computePrayerTimes: computePrayerTimes
  }
}