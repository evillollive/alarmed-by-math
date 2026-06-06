# Alarmed by Math 🔔🧮

**An alarm clock that won't let you go back to sleep until you prove you're awake.**

Alarmed by Math is a small, focused iOS alarm app built with Swift and SwiftUI. The twist: when it goes off, you can't just swat the snooze button. You've got to solve a math problem first. Get it right and the alarm stops. Get it wrong and it resets with a new one. It's simple, a little annoying on purpose, and surprisingly effective at getting you out of bed.

![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4-007AFF?logo=swift&logoColor=white)
![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)

## Quick Start

1. Clone the repo:
   ```bash
   git clone https://github.com/evillollive/alarmed-by-math.git
   ```
2. Open `AlarmedByMath.xcodeproj` in Xcode
3. Build and run on a simulator or device
4. Grant notification permissions when prompted

That's it. No dependencies, no pods, no package manager fuss.

## How it actually works

The flow is intentionally simple so there's nothing between you and the alarm doing its job:

1. **Set an alarm.** Pick a time, give it a label if you want, choose which days it repeats.
2. **It goes off.** Full-screen pulsing UI with sound. Hard to ignore.
3. **Solve to dismiss.** Tap the button to get a random math problem. The alarm keeps ringing until you answer correctly.
4. **Wrong answer?** The problem resets and you try again. No shortcuts.
5. **Walked away?** If you background the app, a follow-up notification re-rings after 5 minutes. You're not getting out of this one.
6. **One-time alarms expire cleanly.** After a one-time alarm fires, it is marked fired and disabled so it doesn't silently roll into future days.

## The clever bits

A few design choices that make this more than just "alarm + quiz":

- **Free difficulty ladder, plus Premium purchase plumbing.** Easy through Expert are available in the free app. Premium is wired as a StoreKit 2 unlock, and any locked Premium alarm is safely normalized back to Expert until the entitlement is active.
- **Repeating schedules.** Set alarms for specific days of the week or leave them as one-time events. The scheduling uses iOS local notifications, so alarms fire even when the app isn't in the foreground.
- **Safer one-time behavior.** One-time alarms are treated as one-shot events and won't auto-reschedule for tomorrow after they have fired.
- **Snooze safety net.** There's no snooze button, but if you try to cheat by closing the app, a follow-up notification catches you five minutes later. It's persistent by design.
- **Configurable challenge ring policy.** You can keep audio ringing while solving, or use auto-snooze and re-ring behavior.
- **Full-screen ringing.** When the alarm fires, the whole screen takes over with a pulsing animation and the current time. It's meant to be unmissable.

## What's under the hood

- **Swift** + **SwiftUI** for the entire UI
- **StoreKit 2** for Premium purchase, restore, and entitlement refresh
- **UserNotifications** for scheduling local alarms
- **AVFoundation** for in-app alarm audio playback
- **UserDefaults** (Codable) for persistence
- Zero external dependencies

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
│   ├── AlarmGate.swift          # Solve-to-dismiss gate state
│   ├── AlarmKitScheduler.swift  # AlarmKit locked-screen alarms (iOS 26.1+)
│   ├── SettingsStore.swift      # Preferences and app settings
│   ├── PremiumPlugin.swift      # Runtime seam for the optional paid add-on
│   └── StatsStore.swift         # Usage stats and milestone tracking
├── Views/
│   ├── ContentView.swift        # Main alarm list with edit/delete/toggle
│   ├── AddAlarmView.swift       # Create & edit alarm form
│   ├── AlarmRingingView.swift   # Full-screen ringing UI
│   ├── MathChallengeView.swift  # Math problem + custom number pad
│   ├── SettingsView.swift       # Themes, sound, test alarm
│   └── StatsView.swift          # Usage stats + hidden easter egg
├── Premium/                     # Synced folder for the private add-on (empty here)
├── PrivacyInfo.xcprivacy        # App Store privacy manifest
└── Assets.xcassets/
```

## Requirements

- iOS 17+
- Xcode 16+ (the locked-screen AlarmKit path builds against the iOS 26 SDK and falls back to chained notifications on iOS 17–25)

## Accessibility

Alarmed by Math is built to be usable for everyone, not just people who can see the screen clearly at 6 AM:

- **VoiceOver labels** on custom controls, including theme rows and the new Premium purchase and restore actions
- **VoiceOver labels on day toggles and number pad controls** so alarm setup and math input stay clear
- **Announcements** for correct and incorrect answers so you don't have to squint at feedback
- **Reduce Motion support** for ringing and challenge animations, because pulsing and shake effects aren't for everybody
- **Dynamic Type** with minimum scale factors so text stays readable at any size
- **Contrast-aware settings cards** and full-row tap targets so the Premium purchase flow stays understandable under low vision and shaky-morning conditions
- **Permission state banner** on the main list when notifications are disabled, so setup problems are visible immediately

## Privacy

Alarmed by Math collects nothing. There are no accounts, no servers, no analytics, and
no network calls — all data (alarms, settings, stats) lives locally in `UserDefaults`.
The bundled [`PrivacyInfo.xcprivacy`](AlarmedByMath/PrivacyInfo.xcprivacy) manifest
declares no tracking, no collected data, and the required-reason `UserDefaults` API
usage, and `ITSAppUsesNonExemptEncryption` is set so uploads skip the export-compliance
prompt.

## Open-source app, separate Premium add-on

This repository is the **complete, free app**. It builds and runs on its own with the full free difficulty ladder (Easy through Expert) and all the alarm machinery. The paid **Premium** ("Whiz") tier, scientific generators and the scientific keypad, lives in a separate **private** repo so it isn't distributed with the open-source code.

It works through a small runtime seam:

- `Services/PremiumPlugin.swift` is a registry the free code consults. There are no build flags or `#if` branches at the call sites.
- `AlarmedByMath/Premium/` and `AlarmedByMathTests/Premium/` are file-system-synchronized Xcode folders. They're tracked (so the build roots always exist) but their `*.swift` contents are gitignored.
- When the private add-on's sources are checked out into those folders, Xcode compiles them into the same app module and they self-register at launch via `@objc(ABMPremiumRegistrar)`. When absent, every Premium path falls back to free behavior, so a Premium alarm is normalized to Expert and the standard keypad is shown.

Because there's a single Xcode project, **any change to the free app automatically applies to the Premium build**, there's no fork to keep in sync. Maintainers with access populate the `Premium/` folders from the private repo's `sync.sh`; everyone else gets a fully working free app.

## Premium setup

The app now includes live StoreKit plumbing for the paid Premium unlock.

- **Product ID:** `com.alarmedbymath.app.whiz`
- **Product type:** non-consumable
- **In-app behavior:** purchase, restore, and entitlement refresh are wired in `SettingsStore`
- **App Store Connect requirement:** create the product with the same ID before expecting live purchases in debug, TestFlight, or production

## License

AGPL-3.0 © Alex Perrault. See [LICENSE](LICENSE) for details.
