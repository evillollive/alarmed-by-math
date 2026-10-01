<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
    <img src="docs/assets/logo.svg" alt="Alarmed by Math" width="360">
  </picture>
</p>

<p align="center">
  <b>An alarm clock that won't let you go back to sleep until you prove you're awake.</b>
</p>

<p align="center">
  <a href="https://github.com/evillollive/alarmed-by-math/actions/workflows/release.yml"><img src="https://github.com/evillollive/alarmed-by-math/actions/workflows/release.yml/badge.svg" alt="Release"></a>
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/SwiftUI-007AFF?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white" alt="iOS 17+">
  <img src="https://img.shields.io/badge/dependencies-none-2ea44f" alt="No dependencies">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/evillollive/alarmed-by-math" alt="License: AGPL v3"></a>
  <a href="https://evillollive.github.io/alarmed-by-math/privacy.html"><img src="https://img.shields.io/badge/privacy-no%20tracking-8A2BE2" alt="Privacy: no tracking"></a>
</p>

# Alarmed by Math

Alarmed by Math is a small, focused iOS alarm app built with Swift and SwiftUI. The twist: when it goes off, you can't just swat the snooze button. You've got to solve a math problem first. Get it right and the alarm stops. Get it wrong and it resets with a new one. It's simple, a little annoying on purpose, and surprisingly effective at getting you out of bed.

<p align="center">
  <img src="docs/assets/demo-preview.svg" alt="Three phone screens: an alarm list, a full-screen ringing alarm, and a math challenge you must solve to dismiss it" width="900">
</p>

> Curious where this is headed? See the [**Roadmap**](ROADMAP.md).

## Contents

- [Quick start](#quick-start)
- [How it actually works](#how-it-actually-works)
- [Free vs Premium](#free-vs-premium)
- [The clever bits](#the-clever-bits)
- [Sound V2](#sound-v2)
- [What's under the hood](#whats-under-the-hood)
- [Project structure](#project-structure)
- [Requirements](#requirements)
- [Local development checks](#local-development-checks)
- [Accessibility](#accessibility)
- [Privacy](#privacy)
- [Open-source app, separate Premium add-on](#open-source-app-separate-premium-add-on)
- [License](#license)

## Quick start

1. Clone the repo:
   ```bash
   git clone https://github.com/evillollive/alarmed-by-math.git
   ```
2. Open `AlarmedByMath.xcodeproj` in Xcode
3. Build and run on a simulator or device
4. Grant alarm access on iOS 26.1+, or notification access on older supported versions

That's it. No dependencies, no pods, no package manager fuss.
If access is denied or scheduling fails, the alarm list shows recovery guidance
and a retry action. A saved alarm is not a guarantee that the system scheduled it.

## How it actually works

The flow is intentionally simple so there's nothing between you and the alarm doing its job:

1. **Set an alarm.** Pick a time, give it a label if you want, choose which days it repeats.
2. **It goes off.** On iOS 26.1+, AlarmKit presents a system alarm, including on
   the Lock Screen. Older supported versions use notification sounds. Opening
   the app presents the ringing screen.
3. **Solve to dismiss.** Tap the button to get a random math problem. The alarm keeps ringing until you answer correctly.
4. **Wrong answer?** The problem resets and you try again. No shortcuts.
5. **Walked away?** If you background the app, a follow-up notification re-rings after 5 minutes. You're not getting out of this one.
6. **One-time alarms expire cleanly.** After a one-time alarm fires, it is marked fired and disabled so it doesn't silently roll into future days.

## Free vs Premium

This repository is the **complete free app** — it builds and runs on its own with the full alarm flow. Premium is an optional one-time StoreKit 2 unlock whose code lives in a separate private companion repo.

| | Free | Premium |
|---|:---:|:---:|
| Solve-to-dismiss alarm flow | ✅ | ✅ |
| Difficulty: Easy → Expert | ✅ | ✅ |
| Repeating & one-time schedules | ✅ | ✅ |
| Themes & full accessibility | ✅ | ✅ |
| Live themed clock in the widget | ✅ | ✅ |
| **Whiz** difficulty | — | ✅ |
| Solve soundtrack from your library | — | ✅ |
| Widget alarms + solve streak | — | ✅ |
| Widget customization (digital/analog, size, date) | — | ✅ |

Locked Premium features present a functional, redacted preview that deep-links to a single paywall, and any locked Premium alarm is safely normalized back to Expert until the entitlement is active.

## The clever bits

A few design choices that make this more than just "alarm + quiz":

- **Silent math practice.** Open **Practice math** at the bottom of the alarm
  list, choose a difficulty and 1-10 problems, and try the same keypad and answer
  rules used by real alarms. Practice stays in memory: it creates no alarms,
  plays no alarm audio, and does not change solve statistics or streaks. Use
  **Done** or Back to leave at any time. Correct answers and retries advance
  only when you choose to continue; Whiz remains gated by the existing Premium
  entitlement and add-on.
- **Copy without surprises.** Swipe right on an alarm, or use its context menu
  or VoiceOver action, to duplicate it. Review the new alarm before saving;
  cancelling the draft leaves the original and its schedule untouched.
- **Your clock preferences.** Alarm times use the device's 12/24-hour format.
  Repeat-day labels and the weekday picker follow the current calendar's
  language and first day of the week. Widgets already use native time formatting.
- **Refined chalkboard artwork.** Deep green, warm chalk, and a golden
  clock-and-right-triangle mark tie the alarm list, ringing screen, and challenge
  together. The editable [vector artwork](docs/assets/chalkboard-mark.svg) is
  included; the installed app icon is unchanged in this first pass.
- **A quieter type system.** App-owned text uses one font design per theme and
  three Dynamic Type sizes: body text, compact headings, and large time/math
  values. Labels use weight and color instead of extra fonts or tiny captions.
  Choice grids adapt to larger text; native controls and customizable widget
  sizes retain their existing behavior.
- **A curated sound collection.** Eight wake sounds cover melodic and insistent
  styles, with separate preview and selection controls. Previewing never changes
  the saved sound; explicitly selecting one updates enabled alarm schedules.
- **Free difficulty ladder, plus a real Premium tier.** Easy through Expert are available in the free app. Premium is a one-time StoreKit 2 unlock, and any locked Premium alarm is safely normalized back to Expert until the entitlement is active. A dedicated paywall is the single upsell surface, and locked features (Whiz difficulty, the solve soundtrack, the widget) deep-link straight into it.
- **Premium solve soundtrack.** Premium users can pick a song from their library to play while they solve the alarm's math. It plays in the foreground only: your phone still wakes you with the dependable bundled alarm sound, because iOS won't start library playback from the lock screen.
- **Premium Home Screen widget with a live, themed clock.** A small or medium widget shows a live current-time clock that mirrors your chosen in-app theme (colors and font), plus your next alarm and solve streak. Premium users can customize it from Settings: a **digital or analog** clock, **small/medium/large** text, an optional **date** line (weekday, short, or full), how many **upcoming alarms** the medium widget lists (1–3), and whether to **show the streak**. The clock shows for everyone; the alarm and streak details are Premium, and the locked state is a functional, redacted preview that taps through to the paywall. The app shares a tiny derived snapshot (theme palette, layout config, and a small buffer of upcoming alarms) with the widget through an App Group and reloads it on launch, scene changes, and alarm/entitlement/streak/theme/widget-setting updates.
- **Repeating schedules.** Set alarms for specific days of the week or leave them as one-time events. The scheduling uses iOS local notifications, so alarms fire even when the app isn't in the foreground.
- **Safer one-time behavior.** One-time alarms are treated as one-shot events and won't auto-reschedule for tomorrow after they have fired.
- **Snooze safety net.** There's no snooze button, but if you try to cheat by closing the app, a follow-up notification catches you five minutes later. It's persistent by design.
- **Configurable challenge ring policy.** You can keep audio ringing while solving, or use auto-snooze and re-ring behavior.
- **Full-screen ringing.** When the alarm fires, the whole screen takes over with a pulsing animation and the current time. It's meant to be unmissable.

## Sound V2

| Style | Sounds |
|---|---|
| Melodic | Chime, Daybreak, Glasshouse, Clockwork |
| Insistent | Bell, Buzz, Roll Call, Ratchet |

Glasshouse uses the approved low-opening-note version without echoes. Ratchet
uses distinct mechanical wake-up strikes rather than the discarded saturated
bass experiment. Chime's original recording and default selection are unchanged.

On first launch after updating, saved Classic selections migrate to Roll Call.
Bell and Buzz keep their settings identifiers but use the approved V2 recordings.
The selected sound applies to every alarm. Previews use media volume, can play
on silent, and stop when dismissed, backgrounded, or interrupted by an alarm.
Scheduled alarms follow their platform's audio controls instead.

Audio-session changes and player preparation run on a serial background queue.
iOS 27 uses the native asynchronous activation/deactivation APIs; earlier
supported versions use the older API off the UI thread. Stopped or superseded
requests cannot start playback from a late callback. A solve soundtrack replaces
foreground wake audio only after it starts successfully, while auto-snooze keeps
its separate policy. Playback failures are surfaced instead of reported as success.

Each new CAF contains three identical copies of the approved eight-second phrase,
for 24 seconds of audio under the notification sound limit. This avoids a long
quiet interval in the older notification-based scheduling path. The seven new
recordings are mono, 44.1 kHz, 16-bit PCM with a -9 dBFS sample-peak ceiling;
that is not a matched-loudness or wake-effectiveness claim. Legacy recordings
remain bundled for previously registered system schedules, but are not choices
in the V2 picker.

The original synthesis is reproducible with
`python3 scripts/generate_alarm_sounds.py` on macOS. The generator checks each
phrase against its approved PCM SHA-256 and verifies lossless CAF conversion.
The generated files are included in the app target, so normal builds need no audio tools.
Actual phone-speaker, locked-screen, and scheduled-alarm checks remain necessary
before release. Music-library solve soundtracks remain a separate Premium feature.

## What's under the hood

| Technology | Used for |
|---|---|
| **Swift** + **SwiftUI** | The entire UI |
| **WidgetKit** + **App Group** | Premium Home Screen widget, sharing a derived snapshot |
| **StoreKit 2** | Premium purchase, restore, and entitlement refresh |
| **UserNotifications** | Scheduling local alarms |
| **AVFoundation** | In-app alarm audio and the Premium solve soundtrack |
| **UserDefaults** (Codable) | Persistence |

Zero external dependencies — no pods, no packages.

## Project structure

```
AlarmedByMath/
├── AlarmedByMathApp.swift       # App entry point, lifecycle handling
├── Theme.swift                  # Theme palettes and color lookups
├── Models/
│   ├── Alarm.swift              # Alarm data model with validation
│   └── MathProblem.swift        # Random math problem generator
├── Services/
│   ├── AlarmStore.swift         # CRUD + persistence for alarms
│   ├── AlarmScheduler.swift     # Notification scheduling, audio, ringing state
│   ├── AudioSessionController.swift # Serialized session changes and player preparation
│   ├── AlarmGate.swift          # Solve-to-dismiss gate state
│   ├── AlarmKitScheduler.swift  # AlarmKit locked-screen alarms (iOS 26.1+)
│   ├── SettingsStore.swift      # Preferences and app settings
│   ├── PremiumPlugin.swift      # Runtime seam for the optional paid add-on
│   ├── WidgetSharedStore.swift  # App Group snapshot shared with the widget
│   ├── WidgetSync.swift         # Derives the snapshot and reloads timelines
│   └── StatsStore.swift         # Usage stats and milestone tracking
├── Views/
│   ├── ContentView.swift        # Main alarm list with edit/delete/toggle
│   ├── AddAlarmView.swift       # Create & edit alarm form
│   ├── AlarmRingingView.swift   # Full-screen ringing UI
│   ├── MathChallengeView.swift  # Math problem + custom number pad
│   ├── MathPracticeView.swift   # Silent, non-persistent challenge practice
│   ├── SettingsView.swift       # Themes, sound, test alarm
│   ├── PaywallView.swift        # Premium upsell sheet + compliance links
│   └── StatsView.swift          # Usage stats + hidden easter egg
├── Premium/                     # Synced folder for the private add-on (empty here)
├── AlarmedByMath.entitlements   # App Group entitlement
├── PrivacyInfo.xcprivacy        # App Store privacy manifest
└── Assets.xcassets/

AlarmedByMathWidget/             # Premium Home Screen widget extension
├── AlarmedByMathWidgetBundle.swift
├── AlarmedByMathWidget.swift    # Timeline provider, themed live clock, digital/analog layouts
├── AlarmedByMathWidget.entitlements
└── Info.plist
```

## Requirements

- iOS 17+
- Xcode 27 or later with the iOS 27 SDK, for the native asynchronous audio-session
  APIs. The deployment minimum remains iOS 17; real-device qualification stays
  on the [roadmap](ROADMAP.md).
- At runtime, iOS 26.1+ uses AlarmKit. iOS 17 through iOS 26.0 uses chained
  notifications, which do not have the same silent-mode and Focus behavior.

## Local development checks

Run the `AlarmedByMath` scheme's unit tests on an installed simulator. The shared
`AlarmedByMathUI` scheme separately checks copy-alarm review/cancellation,
sound preview/selection, silent practice, and the ringing-to-challenge flow,
attaching native screenshots to the result bundle.
Use a dedicated simulator for UI tests because they create and delete sample
alarms and play Test Alarm audio.

Test Alarm is a foreground preview: solving it does not schedule a real re-ring
or contribute to alarm-completion statistics. Simulator checks do not qualify
locked-screen audio, Focus behavior, or physical-device wake reliability.

Silent practice uses a pushed navigation screen, not an additional modal, so
the app's existing full-screen alarm presentation remains above it. The practice
model has no access to the scheduler, audio, or statistics stores.

## Accessibility

Alarmed by Math is built to be usable for everyone, not just people who can see the screen clearly at 6 AM:

- **VoiceOver labels** on custom controls, including theme rows and the new Premium purchase and restore actions
- **VoiceOver labels on day toggles and number pad controls** so alarm setup and math input stay clear
- **Announcements** for correct and incorrect answers so you don't have to squint at feedback
- **Reduce Motion support** for ringing and challenge animations, because pulsing and shake effects aren't for everybody
- **Dynamic Type** with minimum scale factors so text stays readable at any size
- **Contrast-aware settings cards** and full-row tap targets so the Premium purchase flow stays understandable under low vision and shaky-morning conditions
- **Backend-specific setup guidance** distinguishes AlarmKit access from notification
  access and disabled notification sounds. Scheduling failures are visible with
  a retry action, rather than appearing only in logs.
- **Scrollable ringing and challenge screens** keep controls reachable when text
  grows or the available height is small. Repeated submissions are ignored while
  an answer is being processed.

## Privacy

Alarmed by Math collects nothing. There are no accounts, no servers, no analytics, and
no network calls — all data (alarms, settings, stats) lives locally in `UserDefaults`.
The optional Premium solve soundtrack reads your music library only to let you pick and
play a song, and the widget reads a small derived snapshot the app writes to a shared
App Group; neither leaves your device. The bundled
[`PrivacyInfo.xcprivacy`](AlarmedByMath/PrivacyInfo.xcprivacy) manifest
declares no tracking, no collected data, and the required-reason `UserDefaults` API
usage, and `ITSAppUsesNonExemptEncryption` is set so uploads skip the export-compliance
prompt. The hosted [Privacy Policy](https://evillollive.github.io/alarmed-by-math/privacy.html)
says the same in plain language.

## Open-source app, separate Premium add-on

This repository is the complete free app. It builds and runs on its own with Easy through Expert and the full alarm flow.

Premium code lives in a separate private companion repo. The public app includes runtime hooks so premium functionality can be added in private builds, while public builds keep free-safe behavior.

Operational and commercial premium details are intentionally documented only in the private premium repository.

## License

AGPL-3.0 © Alex Perrault. See [LICENSE](LICENSE) for details.
