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

- **Difficulty ladder.** Choose from Easy through Expert. Each step ramps up the math so you can tune exactly how awake you need to be before the alarm will let you go.
- **Repeating schedules.** Set alarms for specific days of the week or leave them as one-time events. The scheduling uses iOS local notifications, so alarms fire even when the app isn't in the foreground.
- **Safer one-time behavior.** One-time alarms are treated as one-shot events and won't auto-reschedule for tomorrow after they have fired.
- **Snooze safety net.** There's no snooze button, but if you try to cheat by closing the app, a follow-up notification catches you five minutes later. It's persistent by design.
- **Configurable challenge ring policy.** You can keep audio ringing while solving, or use auto-snooze and re-ring behavior.
- **Full-screen ringing.** When the alarm fires, the whole screen takes over with a pulsing animation and the current time. It's meant to be unmissable.

## What's under the hood

- **Swift** + **SwiftUI** for the entire UI
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
│   └── StatsStore.swift         # Usage stats and milestone tracking
├── Views/
│   ├── ContentView.swift        # Main alarm list with edit/delete/toggle
│   ├── AddAlarmView.swift       # Create & edit alarm form
│   ├── AlarmRingingView.swift   # Full-screen ringing UI
│   ├── MathChallengeView.swift  # Math problem + custom number pad
│   ├── SettingsView.swift       # Themes, sound, test alarm
│   └── StatsView.swift          # Usage stats + hidden easter egg
├── PrivacyInfo.xcprivacy        # App Store privacy manifest
└── Assets.xcassets/
```

## Requirements

- iOS 17+
- Xcode 16+ (the locked-screen AlarmKit path builds against the iOS 26 SDK and falls back to chained notifications on iOS 17–25)

## Accessibility

Alarmed by Math is built to be usable for everyone, not just people who can see the screen clearly at 6 AM:

- **VoiceOver labels** on custom controls, including theme rows and settings actions
- **VoiceOver labels on day toggles and number pad controls** so alarm setup and math input stay clear
- **Announcements** for correct and incorrect answers so you don't have to squint at feedback
- **Reduce Motion support** for ringing and challenge animations, because pulsing and shake effects aren't for everybody
- **Dynamic Type** with minimum scale factors so text stays readable at any size
- **Contrast-aware settings cards** and full-row tap targets so settings stay understandable under low vision and shaky-morning conditions
- **Permission state banner** on the main list when notifications are disabled, so setup problems are visible immediately

## Privacy

Alarmed by Math collects nothing. There are no accounts, no servers, no analytics, and
no network calls — all data (alarms, settings, stats) lives locally in `UserDefaults`.
The bundled [`PrivacyInfo.xcprivacy`](AlarmedByMath/PrivacyInfo.xcprivacy) manifest
declares no tracking, no collected data, and the required-reason `UserDefaults` API
usage, and `ITSAppUsesNonExemptEncryption` is set so uploads skip the export-compliance
prompt.

## License

AGPL-3.0 © Alex Perrault. See [LICENSE](LICENSE) for details.
