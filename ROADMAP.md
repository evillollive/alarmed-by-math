# Roadmap

Updated October 1, 2026. A short, prioritized plan, not a release commitment.
The modernization update is merged in [#12](https://github.com/evillollive/alarmed-by-math/pull/12)
and included in the **1.7.0 source release, build 6**. Source publication is not
App Store readiness: physical-device and distribution qualification remain open.
See [CHANGELOG.md](CHANGELOG.md) for release details and upgrade notes.

## 1.7.0 source checkpoint: merged, not device-qualified

- Added backend-specific permission guidance, visible scheduling errors and
  retry controls, including notification-capacity warnings.
- Added duplicate-alarm drafts and locale-aware time and weekday formatting.
  A copy is not saved or scheduled until the user reviews and saves it.
- Unified next-occurrence planning across the store, scheduler, and widget.
  New one-time alarms can target tomorrow and retain their intended local day.
  Exact one-shot payloads, conservative legacy migration, midnight expiry,
  travel expiry, and widget forecast rollover are covered locally.
- Added silent practice with difficulty selection, 1-10 problems, explicit
  retry/next controls, and an exit at any time. It shares the real challenge's
  keypad and answer rules but does not schedule, silence, or record alarms.
- Fixed the full-row Practice hit area on wide iPad layouts. The core editing,
  sound, statistics, Premium-sheet, and practice surfaces have scoped iPad mini
  portrait/landscape coverage, including maximum accessibility text.
- Applied the selected refined chalkboard direction to the palette, alarm list,
  ringing screen, and math challenge, with scrollable layouts, answer feedback,
  and a repeated-submission guard. Added original
  [clock-and-geometry vector artwork](docs/assets/chalkboard-mark.svg).
  The selected B3 icon now replaces the old equation icon, with default/dark/tinted
  appearances and matching README branding. Shared geometry also updates the
  analog widget while preserving its working clock hands.
- Simplified app typography to one typeface per active theme and three semantic
  sizes, centralized in `AppTypography`. Removed mixed serif headings and
  monospaced captions, kept large digits for time/math, and made choice grids
  adapt to larger text.
- Moved audio-session transitions and player preparation off the UI thread,
  using native asynchronous APIs on iOS 27 and a serialized legacy path earlier.
  Cancellation IDs prevent stale playback, and soundtrack handoff preserves
  wake audio until the replacement starts. Prepared cancelled players stop
  before the session is released.
- Added regression tests. Direct palette measurements give 7.16:1 or better
  for the new chalkboard text/accent colors against its two backgrounds.
  This is not a full accessibility or device qualification.
- **Local development evidence:** the app and widget build with Xcode 27. Focused
  practice, math, and alarm-policy checks passed on iOS 26.5 and 27.0, as did
  native practice and ringing-to-challenge flows. The practice flow also passed
  at the largest accessibility text size on iOS 27. These are scoped local
  results, not distribution qualification or proof of locked-screen wake behavior.
- **Still next:** skip-next scheduling, remaining theme/widget polish,
  final App Store screenshots, and real-device alarm lifecycle coverage.

## Starting point

The repository already includes repeating and one-time alarms, configurable math
challenges, AlarmKit on iOS 26.1+, notification fallback on older supported
versions, eight themes, stats and the Pythagoras unlock, plus Premium soundtrack
and customizable Home Screen widget integration. These are foundations to improve,
not features to rebuild. Live Premium sales and private-build readiness still
need separate verification.

## 1. Current iOS and trustworthy alarms

- **Modernize the baseline:** build with stable Xcode 27 and target compatibility
  with iOS/iPadOS 27.0.1, the current stable releases at this review. Keep the iOS
  17 deployment minimum unless dropping older devices is explicitly approved.
  Audit AlarmKit API availability, app intents, widget behavior, iPad layouts,
  and concurrency warnings. The audio-session and implicit player-preparation
  warnings are resolved in the locally exercised iOS 26.5/27 playback flows.
  Continue physical-device interruption, audio-route, and wake-reliability
  coverage. Building now requires the iOS 27 SDK; deployment still supports iOS 17.
- **Make alarm readiness visible:** distinguish AlarmKit authorization from
  notification permission, show scheduling failures, and explain how to recover.
  This guidance is included in 1.7.0; retain real-device coverage before distribution.
- **Protect the core behavior:** cover locked/background operation, system Stop,
  snooze/re-ring, overlapping alarms, restart/reopen, daylight-saving changes,
  and timezone changes. Clearly distinguish bundled wake sounds from
  foreground-only library music and the less capable notification fallback,
  including iOS 26.0. Do not promise an unbreakable math gate.
- **Approved clock policy:** use the next valid occurrence when arming a one-shot;
  follow local time when recalculating; skip nonexistent spring-forward times;
  use only the first fall-back occurrence. If travel puts a one-shot's planned
  local day/time in the past, expire it and require explicit re-enabling.
  The user accepted exact one-shot scheduling with reopening after travel to
  recalculate. Native weekly DST delivery still needs physical-device evidence,
  because the system APIs do not expose these policy switches. No finite
  recurrence buffer or reopen-dependent skip-next workaround has been introduced.

**Exit:** local regression coverage plus real-device evidence on current iOS
and representative older supported versions. Simulator or hosted success alone
cannot qualify locked-screen alarm behavior.

## 2. Astra 6 visual refresh, started early

- **Selected identity:** refined chalkboard with the B3 clock mark. The bells
  use right triangles at 65% scale and the central triangle uses 80% scale.
  Icon, in-app mark, analog clock styling, and README logos now share geometry.
- **Reusable art set:** default/dark/tinted PNG icons and SVG branding are
  included in 1.7.0, using the supported asset-catalog path and preserving
  older-iOS compatibility. Optional layered Icon Composer treatments and
  additional milestone/badge art remain later polish, not completed work.
- **Polish the actual app:** the shared three-size typography system is now
  implemented. Continue refining spacing, theme previews, keypad hierarchy,
  and answer feedback. Explore native Liquid Glass for navigation
  and controls where it helps, not behind math that must remain easy to read.
  Carry the selected style into widgets, README art, and App Store screenshots
  captured from the implemented UI rather than invented screens.
- **Judge by usability, not novelty:** check small icons and sleepy one-handed
  use; retain VoiceOver, large Dynamic Type, Reduce Motion and Reduce Transparency.
  Target 4.5:1 normal-text contrast and 3:1 large-text/control contrast.

**Exit:** an approved side-by-side concept, consistent production assets, and
readable core screens across all existing themes. Art exploration can run
alongside compatibility work; it does not need Actions.

## 3. Small, useful feature additions

- **Easier scheduling:** qualify the new duplicate flow, then add skip-next.
  **Approved behavior:** skip only the next occurrence of a repeating alarm,
  then automatically resume its usual schedule. One-time alarms retain their
  existing on/off controls.
  Show the skipped occurrence and actual next-ring date consistently in the
  app and widget. Automatic resumption must not depend on reopening the app.
  Confirm the system scheduling approach and timezone behavior before shipping;
  simply disabling the alarm and restoring it on the next launch is not sufficient.
  The iOS 27 SDK exposes no recurrence start date or exception date. Apple's
  `stop(id:)` documentation preserves repeating schedules but does not explicitly
  establish skipping a future occurrence. A disposable simulator probe could
  not reach scheduling because AlarmKit authorization remained denied. Keep
  this feature deferred pending a real-device probe; no skip behavior has been
  established, and no approximation is being shipped.
- **Better challenge setup:** silent practice is included in 1.7.0, separately
  from Test Alarm. Difficulty and problem count stay within the practice session.
  Private-build Whiz keypad coverage and interruption by an actual scheduled
  device alarm still belong to distribution qualification.
- **Respect device preferences:** localized weekday ordering and system
  12/24-hour time throughout the app and widgets instead of hard-coded English
  labels and AM/PM formatting.

**Exit:** each addition preserves saved alarms, free/Premium boundaries, and
accessible controls, with focused local coverage.

## 4. Later platform polish and release readiness

- Explore Lock Screen/StandBy widget layouts and useful Shortcuts. Consider an
  AlarmKit countdown Live Activity only if the snooze design needs it; do not
  rebuild the existing Home Screen widget or promise a continuously ticking icon.
- Verify purchase/restore, entitlement changes, App Group provisioning, privacy
  declarations, age ratings, and accessibility claims. Prepare signed device
  builds and TestFlight feedback locally. Apple currently lists an April 2027
  deadline for iOS/iPadOS 27 SDK submissions; recheck before App Store submission.

## Sound V2: included in 1.7.0

The approved eight are **Chime, Daybreak, Glasshouse, Clockwork, Bell, Buzz,
Roll Call, and Ratchet**. Glasshouse reverts to the grounded-opening reference
without echoes. Ratchet uses the wake-up-strikes revision, not the saturated grind.
Classic and Pinball are excluded from the new collection.

Approved migration: existing Classic selections become Roll Call; Bell and Buzz
use their new recordings; Chime stays unchanged. The app now has separate
preview/select controls with a visible Stop action and updates enabled schedules
when the user selects a sound.

Seven new CAF assets repeat the exact approved eight-second phrase three times,
for a 24-second file below the notification limit. The repository's generator
verifies approved PCM hashes and lossless conversion. The native sound-picker
flow passed local migration, preview isolation, automatic stop, explicit stop,
and persistence checks on iOS 26.5.

**Remaining distribution gate:** actual phone-speaker, locked-screen, system-volume,
and wake-reliability checks. Signal levels, a waveform, and simulator results
cannot establish that a sound will wake someone. Older recordings remain bundled
for previously registered schedules, but are not offered in the new picker.
The recordings are published as source assets; wake effectiveness is not yet
qualified on a physical device.

## Hosted automation and deferred qualification

| Work | What waits for approval and available minutes |
|---|---|
| Hosted iOS qualification | Add a scoped macOS build/test workflow for the app and widget, with targeted UI/snapshot coverage. There is no checked-in build/test workflow today. |
| Efficient CI policy | Plan PR/default-branch coverage without duplicate push/PR builds, bound matrices and timeouts, cancel superseded runs, and limit artifact retention. Required checks must fail closed; enforcement changes need explicit approval. |
| GitHub release automation | The existing `Release` workflow runs on `v*` tag pushes or manual dispatch and publishes source-release notes only. It does not build, sign, or test the app. |
| Pages and hosted agents | Pages publishes from `main:/docs`; a merge can start a deployment. Account for it before publishing. Hosted Copilot agent/review work needs separate scope and budget approval. |

Local coding, artwork, simulator checks, and device testing do not themselves
require Actions. Manual signing/TestFlight uploads do not require Actions either,
but do require Apple credentials and distribution authorization.

**Budget policy:** before any hosted trigger, estimate every job and matrix leg,
likely reruns and post-merge work, apply runner-specific billing rules, and
obtain a per-task ceiling. Record approval, consumption, and outstanding
reservations in that task's handoff rather than treating an earlier approval
as a standing allowance. Source-publication approval does not authorize a new
hosted qualification workflow or waive device evidence. Billing, quota, and
artifact/cache costs must be checked rather than assumed.

## Platform references

- [Apple releases: stable versions versus betas](https://developer.apple.com/news/releases/)
- [App Store submission requirements](https://developer.apple.com/app-store/submitting/)
- [AlarmKit authorization, scheduling, and system behavior](https://developer.apple.com/videos/play/wwdc2025/230/)
- [AlarmKit stop behavior](https://developer.apple.com/documentation/alarmkit/alarmmanager/stop(id:))
- [Icon Composer and layered artwork](https://developer.apple.com/icon-composer/)
