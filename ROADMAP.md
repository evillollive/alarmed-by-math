# Roadmap

Planned work for Alarmed by Math, roughly in priority order. Security,
accessibility, and testing aren't separate phases here: each item below calls
out what it needs in those areas so they're built in, not bolted on.

## Home Screen widget (live clock)

Goal: put a clock on the home screen next to the app that matches the app
icon's look (white face, black hour ticks, grey hands).

Why it's a widget and not a live icon: iOS app icons are static image assets.
There's no API to render a live clock as the icon, and the App Store would
reject private workarounds. WidgetKit is the supported way to show the current
time on the home screen. The analog hands update on a per-minute timeline, not a
smooth second-hand sweep, because iOS caps how often widgets redraw to save
battery.

The code is small. The real work is wiring a new app-extension target into a
hand-maintained `project.pbxproj` (no XcodeGen / project generator), which is
fiddly and the main source of risk.

### Tier 1: analog clock widget only (recommended first step)
- Matches the icon: white face, black ticks, grey hands, minute-level updates.
- No data sharing needed, so no App Group or extra entitlements.
- Roughly one build-and-verify session, mostly target wiring plus getting a
  clean simulator build.
- ~150 lines: widget bundle + `TimelineProvider` + the clock `View`.
- Risk: medium, almost entirely in the `pbxproj` target surgery.
- Testing: snapshot/preview tests for the clock view at each widget size;
  verify the timeline provider returns sane entries.
- Accessibility: provide an `accessibilityLabel` with the spoken time; respect
  Dynamic Type for any text; check contrast in light and dark.

### Tier 2: clock plus "next alarm"
- Adds an App Group so the widget can read the alarm list, plus writing alarm
  data to the shared container from the app and refreshing the widget timeline
  when alarms change.
- Builds on Tier 1; moderate extra effort.
- Risk: medium. App Group entitlements need a matching provisioning profile to
  run on-device.
- Security: only store the minimum needed (next fire time and label) in the
  shared container; no sensitive data. Treat the App Group as a trust boundary.
- Testing: tests for the shared store read/write and the "next alarm"
  computation; verify behavior with zero, one, and many alarms.
- Accessibility: speak the next alarm time and label; don't rely on color alone
  to show "enabled".

### Tier 3: polish
- Multiple widget sizes, Lock Screen and StandBy variants, light/dark tuning.
- Incremental once Tier 1 exists.

### Caveats
- Widget rendering can be verified on the simulator, but anything provisioning
  related (Tier 2 App Group on-device) needs a real device and signing.
- Analog hands move about once a minute, not a continuous sweep.

## Known limitations to address

- In-app snooze is a no-op on iOS 26, since AlarmKit owns the sound. Decide
  whether snooze should reschedule an AlarmKit alarm instead.
- Multiple simultaneous alarms share a single `activeAlarmID`. Ringing two
  alarms at once isn't modeled cleanly yet.
- Locked-screen ringing, the AlarmKit re-ring loop, and the force-math-on-
  foreground behavior can't be verified in CI or the simulator. They need
  on-device testing on iOS 26.1+ before each release.

## Recently shipped
- Reliable locked-screen alarm via AlarmKit (iOS 26.1+) with a chained-
  notification fallback (iOS 17 to 25) and a strict solve-to-dismiss gate.
- Test Alarm now plays even when the phone is on silent (it uses the in-app
  audio path with the playback audio-session category, which overrides the
  silent switch).
- App icon redesign and a shorter home-screen label ("Alarmed").
