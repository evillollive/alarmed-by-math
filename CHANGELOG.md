# Changelog

Notable changes to the public source app are recorded here. Versions use
semantic versioning; the Xcode build number increases separately.
GitHub source releases do not imply App Store availability or completed
physical-device qualification.

## [1.7.0] - 2026-10-01

Source-code release, build **6**. The app and widget share version **1.7.0**.
This is a minor feature release following 1.6.0, not a signed app distribution.

### Added

- Silent math practice with selectable difficulty and 1-10 problems, using the
  alarm challenge's keypad without scheduling alarms or changing statistics.
- Review-before-save alarm duplication through swipe, context-menu, and
  accessibility actions.
- Backend-specific permission guidance, visible scheduling failures, and retry
  controls, including notification-capacity warnings.
- Default, dark, and tinted B3 clock icons, with matching in-app, widget, and
  README artwork and reproducible asset generation.
- Focused calendar, audio-lifecycle, practice, and iPhone/iPad UI regression
  coverage, including large accessibility text.

### Changed

- Shared next-occurrence planning across the app and widget. New one-time alarms
  can target tomorrow and retain their intended local day instead of silently
  rolling forward after expiry.
- Repeating widget forecasts advance from schedule definitions instead of a
  finite cache of upcoming dates.
- Audio-session transitions and player preparation run off the UI thread, with
  native asynchronous session APIs on iOS 27 and a serialized legacy path.
- Sound V2 offers Chime, Daybreak, Glasshouse, Clockwork, Bell, Buzz, Roll Call,
  and Ratchet, with independent preview, stop, and selection controls.
- Refreshed chalkboard styling and shared three-size typography, adaptive choice
  grids, scrollable challenge screens, and full-width iPad practice navigation.
- Alarm times and weekday controls follow device locale and calendar preferences.
- Building now requires **Xcode 27 and the iOS 27 SDK**. Deployment remains
  **iOS 17+**, using AlarmKit on iOS 26.1+ and notification fallback below it.

### Fixed

- Stopped or superseded audio requests cannot begin playback from late
  callbacks. Wake audio remains active until a replacement solve soundtrack
  starts successfully.
- One-time alarm expiry, conservative legacy migration, and date recalculation
  are consistent across the alarm store, scheduler, and widget.
- Repeated answer submissions are ignored while an answer is being processed.

### Upgrade notes

- Saved Classic sound selections migrate to Roll Call. Bell and Buzz retain
  their settings identifiers with new recordings; Chime is unchanged. Legacy
  audio files remain bundled for previously registered schedules.
- Existing one-time alarms without a stored day retain the legacy today-only
  interpretation. Missed occurrences are not moved to a guessed future day.
- **Open the app after travel or a manual clock change before relying on a
  one-time alarm.** Its submitted date stays fixed until recalculated. A planned
  local day/time that is already past expires until explicitly re-enabled.
- Planning skips nonexistent spring-forward times and uses the first fall-back
  occurrence. Repeating delivery is still controlled by the operating system.

### Qualification and known limitations

- This release provides source only, with no signed IPA, TestFlight build, or
  App Store submission. The optional private Premium add-on is not included.
- Scoped local app/widget builds and simulator checks are development evidence,
  not proof of wake reliability. Locked/background ringing, system Stop,
  snooze/re-ring, overlapping alarms, restart/reopen, Focus, system volume, audio
  routes, and native recurring DST delivery still need physical-device evidence.
- Private Premium purchase/restore, signing and App Group provisioning, final
  App Store screenshots, and distribution compliance remain separate gates.
- Skip-next is deferred and is not part of this release.
- There is no hosted app build/test workflow. The Release workflow publishes
  release notes; Pages deploys documentation. Neither qualifies the iOS app.

Implementation: [#12](https://github.com/evillollive/alarmed-by-math/pull/12).
See [ROADMAP.md](ROADMAP.md) for remaining work and
[earlier GitHub releases](https://github.com/evillollive/alarmed-by-math/releases)
for historical notes.

[1.7.0]: https://github.com/evillollive/alarmed-by-math/compare/v1.6.0...v1.7.0
