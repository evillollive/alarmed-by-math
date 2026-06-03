# Roadmap

Planned work for Alarmed by Math, roughly in priority order. Security,
accessibility, and testing aren't separate phases here: each item below calls
out what it needs in those areas so they're built in, not bolted on.

## Immediate product fixes

### 1. Alarm reliability and controls
- Fix music alarms not working. Confirm whether the failure is in song picking,
  persistence, scheduling metadata, playback routing, or AlarmKit integration.
- Verify whether individual alarm volume actually affects playback. If not,
  decide whether to fix it in the free version or remove the control until it
  works correctly.
- Clean up alarm row formatting, including the missing comma between the alarm
  name and recurrence text.
- Testing: unit tests for persistence and per-alarm settings, plus device
  validation for scheduled alarms, custom audio, silent mode behavior, and
  repeated alarms.
- Accessibility: any volume or music-state UI needs clear labels, VoiceOver
  value announcements, and no color-only state.

### 2. Theme overhaul and contrast pass
- Dark and high-contrast themes currently look too similar. Separate them more
  clearly in palette and emphasis.
- Retro theme is hard to read and needs a full contrast/readability pass.
- Add more playful core palettes, including cute pink and blue-forward options.
- Check every theme against accessibility contrast guidelines before shipping.
- Fix the weird theme-picker tap target so the full row is tappable, not just
  the text on the left.
- Testing: snapshot coverage for all themes in light and dark contexts, plus UI
  tests for the theme picker hit area.
- Accessibility: verify contrast, selected-state clarity, focus order, and
  touch target size across all themes.

### 3. Brand polish
- Adjust the clock tick lengths in the app icon so it reads more clearly as a
  clock at small sizes.
- Re-check the icon and in-app analog clock styling together so they feel like
  one system.
- Testing: verify icon legibility at iPhone home-screen sizes and Spotlight
  search sizes.
- Accessibility: keep strong shape contrast so the icon still reads under lower
  vision conditions.

## Delight and retention

### Hidden easter egg system
- Ship a subtle Pythagoras-themed unlock in the stats screen once the user hits
  either 8 saved alarms or 8 completed alarms.
- Keep the reveal gentle: no loud modal, no flashing, and no interruption to the
  main alarm flow.
- If we want a second delight later, explore a tiny sprite-style add-on that can
  piggyback on the same milestone system instead of introducing a separate one.
- Testing: unit-test the unlock thresholds and copy so the reward doesn't appear
  early or disappear unexpectedly.
- Accessibility: respect Reduce Motion, keep the card readable at large Dynamic
  Type sizes, and preserve strong contrast for the badge and text.

## Whiz (paid) version roadmap

### Whiz feature set
- Scientific calculator and higher "whiz-level" math difficulty live in the paid
  tier.
- Add custom songs as alarms in Whiz, not in the free version.
- Put the home-screen widget in Whiz, not in the free version.

### Whiz widget roadmap

Goal: put a clock on the home screen next to the app that matches the app
icon's look, then optionally expand it to show the next alarm.

Why it's a widget and not a live icon: iOS app icons are static image assets.
There's no API to render a live clock as the icon, and the App Store would
reject private workarounds. WidgetKit is the supported way to show the current
time on the home screen. The analog hands update on a per-minute timeline, not a
smooth second-hand sweep, because iOS caps how often widgets redraw to save
battery.

The code is small. The real work is wiring a new app-extension target into a
hand-maintained `project.pbxproj` (no XcodeGen / project generator), which is
fiddly and the main source of risk.

#### Tier 1: analog clock widget only
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

#### Tier 2: clock plus "next alarm"
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

#### Tier 3: polish
- Multiple widget sizes, Lock Screen and StandBy variants, light/dark tuning.
- Incremental once Tier 1 exists.

#### Whiz caveats
- Widget rendering can be verified on the simulator, but anything provisioning
  related (Tier 2 App Group on-device) needs a real device and signing.
- Analog hands move about once a minute, not a continuous sweep.

## Known limitations to address

- AlarmKit snooze now reschedules a delayed re-ring on iOS 26, but it still
  needs on-device validation to confirm the handoff feels clean while locked,
  in the background, and after reopening the app.
- Multiple simultaneous alarms now queue cleanly in-app, but the locked-screen
  AlarmKit handoff for overlapping alarms still needs on-device validation.
- Whiz purchase, restore, and entitlement syncing are wired in-app now, but
  live sales still need the App Store Connect product configured for the
  `com.alarmedbymath.app.whiz` identifier.
- Locked-screen ringing, the AlarmKit re-ring loop, and the force-math-on-
  foreground behavior can't be verified in CI or the simulator. They need
  on-device testing on iOS 26.1+ before each release.

## Recently shipped
- Reliable locked-screen alarm via AlarmKit (iOS 26.1+) with a chained-
  notification fallback (iOS 17 to 25) and a strict solve-to-dismiss gate.
- Test Alarm now plays even when the phone is on silent (it uses the in-app
  audio path with the playback audio-session category, which overrides the
  silent switch).
- Alarm rows now format named alarms as `Name, Repeat`, and the add/edit flow
  no longer promises per-alarm volume or custom songs on paths the app can't
  honor reliably.
- On the AlarmKit path, opening the math challenge now truly snoozes the active
  alarm by silencing the current ring and scheduling one delayed re-ring.
- Simultaneous alarms now keep a stable in-app queue, so solving one ringing
  alarm cleanly hands off to the next instead of overwriting shared state.
- The app now enforces free-tier vs Whiz-tier difficulty at load, edit, and
  challenge time, and exposes a Whiz status section in Settings.
- Theme picker rows are fully tappable now, dark and high-contrast are more
  clearly separated, retro got a readability pass, and two playful palettes
  (`Bubblegum` and `Bluebird`) were added with contrast checks in tests.
- App icon redesign and a shorter home-screen label ("Alarmed").
- App icon clock markers were lengthened so the clock reads more clearly at home-screen and Spotlight sizes.
- Stats now hide a low-motion Pythagoras easter egg that unlocks after 8 saved alarms or 8 completed alarms, with unit-test coverage for the milestone logic.
- App Store readiness pass: added a `PrivacyInfo.xcprivacy` manifest (no tracking, no
  data collection, `UserDefaults` required-reason declared), set
  `ITSAppUsesNonExemptEncryption = false` for friction-free uploads, and cleared the
  remaining iOS 17 `onChange` deprecation warnings for a clean build.
- Whiz now ships dormant: the purchase UI only appears once a live App Store product
  loads, and the Settings copy no longer advertises unbuilt features, so the app ships
  free-only until the paid tier is real.
- Hardened the save path so scheduling always uses the persisted, normalized alarm from
  the store (`AlarmStore.alarmForScheduling`), preventing already-expired one-time
  alarms from being re-scheduled, with regression tests.
