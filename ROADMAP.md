# Roadmap

Updated October 1, 2026. This is the outstanding-work tracker, not a release
commitment. **[1.7.0, build 6](https://github.com/evillollive/alarmed-by-math/releases/tag/v1.7.0)
is published as source only.** It is not a signed app, TestFlight build, or
App Store release. See [CHANGELOG.md](CHANGELOG.md) for shipped changes.

## Resume here

| Available next session | Start with | Dependency |
|---|---|---|
| Local development only | A11Y-1, then A11Y-2 and COMPAT-1 | No hosted budget needed |
| Physical iPhone available | ALARM-1 through ALARM-6, then SKIP-1 | Authorized device build and permission to exercise alarms/audio |
| Private Premium and Apple credentials available | DIST-1 and DIST-2 | Access to the private add-on and signing resources |
| Preparing store materials | DESIGN-1, then DIST-3 and DIST-4 | Implemented UI and evidence for public claims |
| Hosted qualification approved | CI-1, then CI-2 | Separate CI scope and per-task runner-minute approval |

Work on one bounded item at a time. Keep its ID when adding findings. Check it
off only after recording the tested commit, device/OS or simulator, result, and
remaining limitations in a linked issue, PR, or evidence artifact. A blocker
is not a pass. Add any newly discovered follow-up here before ending a session.
Completed implementation does not close a separate qualification item.

## Completed source baseline

The modernization implementation is merged in
[#12](https://github.com/evillollive/alarmed-by-math/pull/12); versioning,
changelog, and source-release housekeeping are merged in
[#13](https://github.com/evillollive/alarmed-by-math/pull/13).
Do not rebuild these features when resuming:

- [x] Backend-specific permission guidance, scheduling errors, retry controls,
  and notification-capacity warnings.
- [x] Review-before-save alarm duplication and locale-aware time/weekday controls.
- [x] Shared app/widget calendar planning, intended-day one-time alarms,
  conservative migration, expiry, and advancing widget forecasts.
- [x] Silent practice with difficulty selection, 1-10 problems, explicit
  retry/next controls, and no alarm scheduling, audio, or statistics side effects.
- [x] Full-width iPad Practice navigation and scoped portrait, landscape, and
  maximum-accessibility-text coverage of the core screens.
- [x] B3 default/dark/tinted icons, shared app/widget/README geometry, refreshed
  chalkboard styling, scrollable challenges, and repeated-submission protection.
- [x] One font design per active theme and three semantic Dynamic Type sizes
  through `AppTypography`, with adaptive choice grids.
- [x] Off-main-thread audio-session transitions and player preparation,
  cancellation-safe callbacks, and reliable foreground soundtrack handoff.
- [x] Sound V2 assets, reproducible generation, sound migration, and separate
  preview/select/stop controls.
- [x] Version 1.7.0 (6), README, changelog, annotated release tag, curated source
  release notes, and post-merge Pages publication.

**Evidence already available:** Xcode 27 app/widget builds; scoped iOS 26.5 and
27.0 calendar, practice, audio, and UI checks; and iPad mini layout coverage.
Chalkboard palette measurements reached at least 7.16:1 for the measured
text/accent-background pairs. These are not a complete all-theme accessibility
audit, hosted iOS qualification, or physical-device wake qualification.

The existing free app also includes eight themes, statistics, and the Pythagoras
unlock. The Premium integration already supports Whiz, a foreground solve
soundtrack, and a customizable Home Screen widget. Live sales and private-build
readiness are still unverified.

## Priority 1: physical-device alarm qualification

**Status:** open distribution gates. Local simulator results cannot close them.
Cover current stable iOS and representative older supported versions, including
the AlarmKit boundary and notification fallback on iOS 26.0 and earlier.

- [ ] **ALARM-1: Locked/background lifecycle.** Exercise scheduled one-time and
  repeating alarms with the app foregrounded, backgrounded, and the phone locked.
  Cover system Stop, keep-ringing versus auto-snooze, re-ring cancellation after
  solving, overlapping alarms, and restart/reopen. Record delivery and recovery
  behavior rather than assuming an unbreakable math gate.
- [ ] **ALARM-2: Sound and audio routes.** Evaluate all eight Sound V2 recordings
  through an actual phone speaker, including scheduled/locked playback, silent
  mode, Focus, system volume, route changes, and interruptions. Check preview
  cancellation and alarm priority on device. Record listening results separately
  from signal levels; a waveform or simulator cannot prove wake effectiveness.
- [ ] **ALARM-3: Calendar delivery.** Verify native weekly DST behavior,
  spring-forward gaps, first fall-back occurrence, midnight expiry, travel, and
  manual clock/time-zone changes. Compare app/widget forecasts with actual
  delivery and verify the documented reopen requirement for fixed one-time dates.
- [ ] **ALARM-4: Permission and scheduling recovery.** Exercise denied/revoked
  AlarmKit authorization, notification permissions/sounds, capacity limits, and
  scheduling failures. Confirm guidance and retries reflect actual scheduling,
  not merely that an alarm was saved.
- [ ] **ALARM-5: Existing-user upgrade.** Upgrade saved alarms/settings from the
  previous version. Verify undated one-time migration, expired alarms staying
  off, sound migration, legacy scheduled sound assets, and schedule changes when
  a new sound is selected. Preserve saved alarms and free/Premium boundaries.
- [ ] **ALARM-6: Practice and duplication on device.** Interrupt practice with
  an actual scheduled alarm; confirm the alarm takes precedence. Qualify
  duplicate-save/cancel behavior and confirm practice/Test Alarm do not change
  real completion statistics. Private Whiz coverage belongs to DIST-2.

**Done when:** repeatable device results and any failures are recorded against
a specific build, with regressions fixed and rechecked. Do not substitute a
successful source-release or Pages job for this evidence.

## Priority 2: compatibility, accessibility, and visual finish

**Status:** ready for local work. Retain the approved design rather than starting
another redesign. These checks can proceed while physical-device work is blocked.

- [ ] **COMPAT-1: Supported-platform pass.** Recheck the then-current stable
  Xcode/iOS/iPadOS versions and representative older supported runtimes.
  Audit AlarmKit availability, app intents, widget refresh, iPhone/iPad layouts,
  and concurrency warnings beyond the paths already exercised. Keep iOS 17
  support unless a minimum-version change is explicitly approved.
- [ ] **A11Y-1: Full VoiceOver pass.** Review alarm setup, duplication, settings,
  sound preview/selection, practice, ringing/challenge, statistics, paywall, and
  widget surfaces. Record labels, reading/focus order, adjustable controls,
  announcements, and any interaction that cannot be completed.
- [ ] **A11Y-2: All-theme readability.** Check all eight themes at large Dynamic
  Type sizes, including maximum accessibility text, on small phones and iPad
  portrait/landscape. Verify clipping, tap targets, keypad hierarchy, and answer
  feedback; measure at least 4.5:1 normal text and 3:1 large text/control contrast.
  The measured chalkboard pairs are not evidence for every theme.
- [ ] **A11Y-3: Device accessibility preferences.** Exercise Reduce Motion and
  Reduce Transparency across ringing, challenges, settings, and widget styling.
  Confirm critical state remains understandable without motion/translucency.
- [ ] **COMPAT-2: Locale/calendar pass.** Verify system 12/24-hour formats,
  localized weekday ordering, first-day-of-week changes, and consistent
  app/widget date presentation without changing the agreed scheduling policy.
- [ ] **DESIGN-1: Production UI polish.** Finish spacing, theme previews,
  keypad/answer hierarchy, and widget consistency. Review small installed icons
  and sleepy one-handed use. Keep a side-by-side review of actual implemented
  screens; update README illustrations if final UI changes make them inaccurate.

**Done when:** the core screens are usable across the covered themes, devices,
and accessibility settings, with scoped evidence and remaining gaps recorded.
Final store screenshots follow this work in DIST-3.

## Priority 3: skip-next, blocked on system behavior

**Status:** deferred, not shipped in 1.7.0. This feature is not a prerequisite for
qualifying the existing release. Do not implement a reopen-dependent substitute.

- [ ] **SKIP-1: Establish the scheduling mechanism.** On an authorized physical
  device, determine whether the system can skip a future repeating occurrence
  while preserving later occurrences. Verify timezone/DST behavior and continued
  scheduling without reopening the app. Decide explicitly whether the
  notification fallback can support the same behavior.
- [ ] **SKIP-2: Implement only after SKIP-1 passes.** Skip exactly the next
  repeating occurrence, automatically resume the normal schedule, and show the
  skipped occurrence and actual next-ring date consistently in the app/widget.
  Leave one-time on/off controls unchanged. Add regression and device coverage.

**Known blocker:** the iOS 27 SDK exposes no recurrence start or exception date.
Apple documents `stop(id:)` preserving repeating schedules, but not explicitly
skipping a future occurrence. The simulator probe stopped at denied AlarmKit
authorization, so it established no skip behavior. Disabling and restoring on
next launch, or introducing a finite recurrence buffer, is not the approved
solution. If a dependable mechanism is unavailable, keep this item deferred.

## Priority 4: private Premium and distribution readiness

**Status:** separate from the public source release. Requires the relevant
private-repository access, Apple credentials, and distribution authorization.
Keep operational and commercial Premium details in the private repository.

- [ ] **DIST-1: Signing and provisioning.** Prepare a signed device build with
  matching app/widget versions, correct App Group provisioning, and working
  shared data. This enables the physical-device and private-build checks.
- [ ] **DIST-2: Premium qualification.** Verify purchase/restore, entitlement
  changes, locked-feature fallback, Whiz keypad/orientation, foreground library
  soundtrack handoff/interruption, widget customization, and paywall deep links.
  Confirm scheduled wake audio remains bundled sound, not library playback.
  Check private-build practice behavior and free/Premium boundaries.
- [ ] **DIST-3: Final screenshots.** After DESIGN-1 and the accessibility pass,
  capture actual app screens for supported store device sizes. Use the approved
  branding and implemented UI, not illustrative mockups or invented screens.
- [ ] **DIST-4: Store declarations and requirements.** Verify privacy manifests
  and policy, age ratings, accessibility claims, and current SDK/submission
  requirements. The prior review noted an April 2027 iOS/iPadOS 27 SDK deadline;
  recheck Apple's guidance before submission instead of assuming it is unchanged.
- [ ] **DIST-5: TestFlight and release decision.** With an authorized signed
  build, collect TestFlight feedback and resolve blockers. Before App Store
  submission, review device, compatibility, accessibility, and Premium evidence,
  approved CI requirements, declarations, and screenshots. Obtain distribution
  authorization separately; source publication is not that authorization.

## Priority 5: hosted iOS qualification and CI policy

**Status:** no hosted app build/test workflow exists. Requires explicit scope
approval and a new runner-minute budget before configuring or triggering work.

- [ ] **CI-1: Design the qualification policy.** Define required app/widget
  checks and targeted unit/UI/snapshot coverage, account for every macOS matrix
  leg and setup/build, and avoid duplicate PR/push builds. Include required
  default-branch or merge-queue coverage where applicable, change-aware selection,
  timeouts, superseded-run concurrency, and limited artifact retention.
  Obtain approval for enforcement changes; skipped/cancelled work is not a pass.
- [ ] **CI-2: Implement and obtain hosted evidence.** After CI-1 approval,
  add the scoped workflow and approved required checks. Record complete run
  receipts and actual consumption. Diagnose failures before requesting reruns;
  budget for whole-workflow reruns when the qualification policy requires them.

**Already operational:** `Release` runs on `v*` tag pushes or manual dispatch and
publishes source-release notes only. Pages publishes from `main:/docs`, and a
merge can trigger it. Neither builds, signs, or qualifies the iOS app.
Hosted Copilot agents/reviews are separate optional work, not implicitly approved.

**Budget policy:** obtain a per-task ceiling before any hosted trigger, including
publication and post-merge work. Record approval, consumption, reservations, and
remaining allowance in the task handoff. Earlier approval is not a standing
allowance; account for billing rules and storage/cache costs instead of assuming
they are free. Local coding, art, simulator/device work, and manual
signing/TestFlight uploads do not themselves require Actions, but signing and
distribution still require their own access and authorization.

## Optional later enhancements

These are exploratory ideas, not prerequisites for distributing the existing
app. Select scope explicitly before implementation.

- [ ] **LATER-1:** Explore Lock Screen and StandBy widget layouts without
  rebuilding the existing customizable Home Screen widget.
- [ ] **LATER-2:** Explore useful Shortcuts.
- [ ] **LATER-3:** Consider an AlarmKit countdown Live Activity only if the
  snooze design needs it.
- [ ] **LATER-4:** Consider layered Icon Composer treatments and additional
  milestone/badge art, preserving older-iOS asset compatibility.
- [ ] **LATER-5:** Explore native Liquid Glass for navigation/controls only where
  it improves usability, not behind math that must remain easy to read.

## Approved decisions to preserve

**Clock policy:** arm the next valid local occurrence; skip nonexistent
spring-forward times and use the first fall-back occurrence. One-time alarms
retain an intended local day and an exact submitted date. Open the app after
travel or a manual clock change to recalculate; a past intended local day/time
expires until explicitly re-enabled. Legacy undated alarms use the conservative
today-only interpretation. Native weekly delivery remains system-managed.

**Visual identity:** refined chalkboard, B3 clock mark, right-triangle bells at
65% scale and face triangle at 80%, with shared icon/app/widget/README geometry.
Keep one typeface per active theme and the three semantic sizes.

**Sound V2:** Chime, Daybreak, Glasshouse, Clockwork, Bell, Buzz, Roll Call, and
Ratchet. Glasshouse keeps the grounded opening without echoes; Ratchet uses
wake-up strikes, not the saturated grind. Classic migrates to Roll Call; Bell
and Buzz use new recordings; Chime is unchanged. Classic and Pinball are not
offered in the new picker, while legacy assets stay bundled for existing
schedules. The seven new CAFs repeat an approved eight-second phrase three times
for 24 seconds; the generator verifies approved PCM hashes and lossless
conversion. Do not silently revise selected sounds as part of qualification.

## Platform references

- [Apple releases: stable versions versus betas](https://developer.apple.com/news/releases/)
- [App Store submission requirements](https://developer.apple.com/app-store/submitting/)
- [AlarmKit authorization, scheduling, and system behavior](https://developer.apple.com/videos/play/wwdc2025/230/)
- [AlarmKit stop behavior](https://developer.apple.com/documentation/alarmkit/alarmmanager/stop(id:))
- [Icon Composer and layered artwork](https://developer.apple.com/icon-composer/)
