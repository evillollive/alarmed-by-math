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

## The clever bits

A few design choices that make this more than just "alarm + quiz":

- **Three difficulty levels.** Easy sticks to addition. Medium mixes in subtraction and multiplication. Hard throws bigger numbers at you. Pick the level that matches how stubborn your sleep habits are.
- **Repeating schedules.** Set alarms for specific days of the week or leave them as one-time events. The scheduling uses iOS local notifications, so alarms fire even when the app isn't in the foreground.
- **Snooze safety net.** There's no snooze button, but if you try to cheat by closing the app, a follow-up notification catches you five minutes later. It's persistent by design.
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
├── Models/
│   ├── Alarm.swift              # Alarm data model with validation
│   └── MathProblem.swift        # Random math problem generator
├── Services/
│   ├── AlarmScheduler.swift     # Notification scheduling, audio, ringing state
│   └── AlarmStore.swift         # CRUD + persistence for alarms
├── Views/
│   ├── ContentView.swift        # Main alarm list with edit/delete/toggle
│   ├── AddAlarmView.swift       # Create & edit alarm form
│   ├── AlarmRingingView.swift   # Full-screen ringing UI
│   └── MathChallengeView.swift  # Math problem + custom number pad
└── Assets.xcassets/
```

## Requirements

- iOS 16+
- Xcode 15+

## Accessibility

Alarmed by Math is built to be usable for everyone, not just people who can see the screen clearly at 6 AM:

- **VoiceOver labels** on all custom controls (number pad, day toggles)
- **Announcements** for correct and incorrect answers so you don't have to squint at feedback
- **Reduce Motion** support, because pulsing animations aren't for everybody
- **Dynamic Type** with minimum scale factors so text stays readable at any size

## License

AGPL-3.0 © Alex Perrault. See [LICENSE](LICENSE) for details.
