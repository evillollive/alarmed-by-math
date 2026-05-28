# Alarmed by Math 🔔🧮

An iOS alarm app that forces you to solve a math problem before you can dismiss the alarm — no more sleeping through snooze.

## Features

- **Math challenge dismiss** — solve a randomly generated math problem to turn off your alarm
- **Difficulty levels** — easy (addition), medium (addition/subtraction/multiplication), and hard (larger numbers)
- **Repeating alarms** — set alarms for specific days of the week or as one-time events
- **Custom labels** — name your alarms for easy identification
- **Snooze safety net** — if you background the app, a follow-up notification re-rings after 5 minutes
- **Full-screen ringing** — pulsing alarm UI with current time display

## How It Works

1. **Set an alarm** — pick a time, optional label, and repeat days
2. **Alarm rings** — full-screen alert with sound when the time arrives
3. **Solve to dismiss** — tap "Solve to Dismiss" to get a random math problem
4. **Answer correctly** — the alarm only stops when you enter the right answer
5. **Wrong answer?** — the problem resets and you try again

## Tech Stack

- **Swift** + **SwiftUI**
- **UserNotifications** for local alarm scheduling
- **AVFoundation** for in-app alarm audio
- Persistence via `UserDefaults` (Codable)
- No external dependencies

## Project Structure

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

## Getting Started

1. Clone the repo:
   ```bash
   git clone https://github.com/evillollive/alarmed-by-math.git
   ```
2. Open `AlarmedByMath.xcodeproj` in Xcode
3. Build and run on a simulator or device
4. Grant notification permissions when prompted

## Accessibility

- VoiceOver labels on all custom controls (number pad, day toggles)
- Accessibility announcements for correct/incorrect answers
- Respects **Reduce Motion** system setting
- Dynamic Type support with minimum scale factors

## License

See [LICENSE](LICENSE) for details.
