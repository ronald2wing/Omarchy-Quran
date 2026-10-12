// tests/test_prayer_time.js — prayer-time.js coordinate helpers tests.
const PT = require("../prayer-time.js")

let pass = 0
let fail = 0

function ok(name, cond) {
  if (cond) {
    pass++
    console.log("PASS " + name)
  } else {
    fail++
    console.log("FAIL " + name)
  }
}

function eq(name, actual, expected, tol) {
  tol = tol || 0.0001
  const a = typeof actual === "number" ? actual : JSON.stringify(actual)
  const e = typeof expected === "number" ? expected : JSON.stringify(expected)
  if (typeof actual === "number" && typeof expected === "number") {
    if (Math.abs(actual - expected) < tol) {
      pass++
      console.log("PASS " + name)
    } else {
      fail++
      console.log("FAIL " + name + " — got " + actual + ", want " + expected)
    }
  } else if (a === e) {
    pass++
    console.log("PASS " + name)
  } else {
    fail++
    console.log("FAIL " + name + " — got " + a + ", want " + e)
  }
}

// --- parseIso6709 ------------------------------------------------------------

// Standard ISO 6709 compact with seconds.
const ny = PT.parseIso6709("+404251-0740023")
ok("parseIso6709 normal returns non-null", ny !== null)
eq("parseIso6709 lat", ny.latitude, 40.0 + 42/60 + 51/3600)
eq("parseIso6709 lon", ny.longitude, -(74.0 + 0/60 + 23/3600))

// Without seconds (minutes only).
const noSec = PT.parseIso6709("+4042-07400")
ok("parseIso6709 no-seconds returns non-null", noSec !== null)
eq("parseIso6709 no-sec lat", noSec.latitude, 40.0 + 42/60)
eq("parseIso6709 no-sec lon", noSec.longitude, -(74.0 + 0/60))

// Negative latitude.
const negLat = PT.parseIso6709("-3355+01825")
ok("parseIso6709 negative lat returns non-null", negLat !== null)
eq("parseIso6709 neg lat", negLat.latitude, -(33.0 + 55/60))
eq("parseIso6709 neg lat lon", negLat.longitude, 18.0 + 25/60)

// Equator / Greenwich.
const zero = PT.parseIso6709("+0000+00000")
ok("parseIso6709 zero returns non-null", zero !== null)
eq("parseIso6709 zero lat", zero.latitude, 0)
eq("parseIso6709 zero lon", zero.longitude, 0)

// --- malformed / edge cases ---
ok("parseIso6709 empty → null", PT.parseIso6709("") === null)
ok("parseIso6709 garbage → null", PT.parseIso6709("garbage") === null)
ok("parseIso6709 number → null", PT.parseIso6709(123) === null)
ok("parseIso6709 null → null", PT.parseIso6709(null) === null)
ok("parseIso6709 undefined → null", PT.parseIso6709(undefined) === null)

// Single sign only.
ok("parseIso6709 '+4042' → null", PT.parseIso6709("+4042") === null)

// Out of range.
ok("parseIso6709 out-of-range lat → null", PT.parseIso6709("+9142+00000") === null)
ok("parseIso6709 out-of-range lon → null", PT.parseIso6709("+0000+18100") === null)

// --- resolveTimezoneCoordinate -----------------------------------------------

const sampleTab = [
  "US\t+404251-0740023\tAmerica/New_York\tEastern (most areas)",
  "US\t+340308-1181434\tAmerica/Los_Angeles\tPacific",
  "# comment line",
  "GB\t+513030-0000731\tEurope/London",
  ""
].join("\n")

const nyResolved = PT.resolveTimezoneCoordinate(sampleTab, "America/New_York")
ok("resolveTimezoneCoordinate found", nyResolved !== null)
eq("resolveTimezoneCoordinate NY lat", nyResolved.latitude, 40.0 + 42/60 + 51/3600)
eq("resolveTimezoneCoordinate NY lon", nyResolved.longitude, -(74.0 + 0/60 + 23/3600))

const london = PT.resolveTimezoneCoordinate(sampleTab, "Europe/London")
ok("resolveTimezoneCoordinate London found", london !== null)
eq("resolveTimezoneCoordinate London lat", london.latitude, 51.0 + 30/60 + 30/3600)
eq("resolveTimezoneCoordinate London lon", london.longitude, -(0.0 + 7/60 + 31/3600))

ok("resolveTimezoneCoordinate unknown tz → null",
   PT.resolveTimezoneCoordinate(sampleTab, "Mars/Olympus") === null)
ok("resolveTimezoneCoordinate empty tz → null",
   PT.resolveTimezoneCoordinate(sampleTab, "") === null)
ok("resolveTimezoneCoordinate null args → null",
   PT.resolveTimezoneCoordinate(null, null) === null)

// Comment lines ignored: this test verifies that '#' lines don't match.
ok("resolveTimezoneCoordinate comments ignored",
   PT.resolveTimezoneCoordinate("# GB\t+513030-0000731\tEurope/London\n", "Europe/London") === null)

// --- computePrayerTimes still works ------------------------------------------
const times = PT.computePrayerTimes(new Date(2025, 0, 1), 21.4225, 39.8262) // Makkah
ok("computePrayerTimes returns object", times !== null && typeof times === "object")
ok("computePrayerTimes has fajr", typeof times.fajr === "string" && times.fajr.match(/^\d{2}:\d{2}$/))
ok("computePrayerTimes has sunrise", typeof times.sunrise === "string")
ok("computePrayerTimes has dhuhr", typeof times.dhuhr === "string")
ok("computePrayerTimes has asr", typeof times.asr === "string")
ok("computePrayerTimes has maghrib", typeof times.maghrib === "string")
ok("computePrayerTimes has isha", typeof times.isha === "string")

console.log(fail === 0 ? `\n${pass} passed` : `\n${pass} passed, ${fail} failed`)
process.exit(fail === 0 ? 0 : 1)