# Keybeat ❤️⌨️

A heart-rate monitor for your typing. Keybeat sits in your Mac's menu bar and
tracks your words-per-minute like a fitness tracker tracks your pulse — resting
rate, daily rhythm, personal records, and a hangover detector.

It is a joke. It is also a real, working utility.

## Privacy — read this first

Keybeat needs the **Input Monitoring** permission, which is the same class of
permission a keylogger would need. So here is exactly what it does, verifiably:

- **macOS hands the app every key event, including which key it was — that's
  how the API works. Keybeat deliberately discards everything except a +1 to a
  counter.** The one handler that touches keyboard events is in
  [`Keybeat/KeystrokeMonitor.swift`](Keybeat/KeystrokeMonitor.swift) — it reads
  only the event type and the autorepeat flag. Read it yourself; it's short.
- **Passwords are invisible by design.** macOS Secure Keyboard Entry means
  keystrokes in password fields (and secure terminals) never reach this app at
  the OS level. They aren't counted because they can't be seen.
- **Nothing leaves your Mac.** No network calls, no analytics, no crash
  reporting, no auto-update phone-home. Grep the source for `URLSession` — 
  there isn't one.
- **The stored data is plain SQLite** at
  `~/Library/Application Support/Keybeat/keybeat.sqlite`: one row per minute —
  timestamp, keystroke count, active seconds. There is nowhere in the schema to
  put key identity. Note that per-minute activity counts still reveal *when*
  you type (that's the whole gag — night-owl badges and all), so treat the file
  like any personal log.
- The permission is revocable any time in System Settings → Privacy & Security
  → Input Monitoring.

## Install

**Build from source (recommended):**

1. Clone this repo and open `Keybeat.xcodeproj` in Xcode 15+.
2. Under Signing & Capabilities, select your own team — any free Apple ID
   works (Team dropdown → Add an Account…). **Don't skip this**: with a team
   selected, macOS ties the Input Monitoring permission to your stable signing
   identity and it survives rebuilds. With "Sign to Run Locally" (ad-hoc),
   every rebuild is a new identity and you'll re-grant the permission each time.
3. Run. Keybeat appears in your menu bar and walks you through the one
   permission it needs.

**Troubleshooting — "the toggle is on but nothing counts":** macOS binds the
permission to the app's code signature, and System Settings will happily show
a stale grant from a previous build as still enabled (toggling it does
nothing). Fix: in System Settings → Privacy & Security → Input Monitoring,
select the Keybeat row and remove it with the "–" button, then let Keybeat
request it fresh and relaunch. This is a macOS TCC quirk, not a Keybeat bug —
see any discussion of "TCC designated requirement" for the gory details.

**Downloaded builds:** unsigned apps from GitHub Releases are blocked by
Gatekeeper on modern macOS — after the "not opened" dialog, go to
System Settings → Privacy & Security, scroll to Security, and click
**Open Anyway**. Move the app to /Applications first, or the permission grant
won't stick (App Translocation).

## Stats

- **Live WPM** in the menu bar (standard definition: 5 keystrokes = 1 word,
  idle gaps over 5s excluded — this is gross WPM; an ambient counter can't see
  typos, so no clinical accuracy is claimed)
- **Today's rhythm** — WPM by hour of day
- **Fitness trend** — daily WPM over the last 30 days
- **KeyFit Score™** — a composite of speed, volume, and consistency with one
  decimal of entirely unearned precision
- **🔥 Typing streaks** — consecutive days over 1,000 keystrokes, plus a count
  of your "rest days" this month. It notices. It always notices.
- **Personal records** — peak minute, with timestamp for maximum shame
- **🦉 REM typing** — keystrokes between 1 and 5am
- **🥴 Hangover detection** — weekend-morning WPM vs. your weekday baseline
  (needs 14 days of data before it starts diagnosing; occasionally wrong,
  which is funnier)
- **📋 Weekly Health Report** — a Sunday-evening macOS notification with your
  week-over-week trend, in the caring voice of a fitness wearable that is
  disappointed in you (asks for the standard notifications permission; skip it
  and the same line just lives in the stats window)

## Disclaimers

Keybeat is a parody of health trackers. It measures typing speed, not your
actual health. It has no affiliation with any actual health product, and no
opinion about your actual heart.

MIT licensed.
