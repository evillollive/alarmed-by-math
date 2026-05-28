import SwiftUI

/// Presents a random math problem that the user must solve correctly to dismiss the alarm.
///
/// Behavior:
/// - The alarm sound **keeps playing** while this view is shown.
/// - A snooze notification is scheduled in case the user backgrounds the app.
/// - A correct answer cancels the snooze notification and fully dismisses the alarm.
/// - A wrong answer shakes the input field, generates a new problem, and lets the user try again.
struct MathChallengeView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler: AlarmScheduler
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var problem     = MathProblem.generate()
    @State private var userInput   = ""
    @State private var isWrong     = false
    @State private var hasSnoozed  = false
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                header
                    .padding(.top, 40)

                Spacer()

                // Math expression
                Text(problem.expression)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal)
                    .accessibilityLabel("Solve: \(problem.expression)")

                // Answer display box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWrong ? Color.red : Color(.systemGray4), lineWidth: 2)
                        .frame(height: 64)

                    Text(userInput.isEmpty ? "?" : userInput)
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundColor(userInput.isEmpty ? .secondary : .primary)
                }
                .padding(.horizontal, 60)
                .modifier(ShakeModifier(active: isWrong, reduceMotion: reduceMotion))
                .accessibilityLabel("Your answer: \(userInput.isEmpty ? "empty" : userInput)")

                Spacer()

                // Custom number pad
                NumberPad(input: $userInput, onSubmit: checkAnswer)
                    .padding(.bottom, 20)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear(perform: scheduleSnoozeIfNeeded)
        .onChange(of: showSuccess) { _, solved in
            guard solved else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Mark one-time alarms as fired
                if let alarmID = scheduler.activeAlarmID,
                   let alarm = alarmStore.alarm(forID: alarmID),
                   alarm.isOneTime {
                    alarmStore.markFired(alarm)
                }
                scheduler.dismiss()
                dismiss()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Text("Solve to Dismiss")
                .font(.headline)
                .foregroundColor(.secondary)

            if hasSnoozed {
                Label(
                    "Alarm will re-ring if not solved",
                    systemImage: "moon.zzz.fill"
                )
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Logic

    /// Schedules a snooze notification as a safety net, but does NOT stop the alarm sound.
    private func scheduleSnoozeIfNeeded() {
        guard !hasSnoozed else { return }
        hasSnoozed = true
        scheduler.snooze()
    }

    private func checkAnswer() {
        guard let answer = Int(userInput) else {
            triggerWrong()
            return
        }
        if answer == problem.answer {
            showSuccess = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "Correct! Alarm dismissed.")
        } else {
            triggerWrong()
        }
    }

    private func triggerWrong() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        UIAccessibility.post(notification: .announcement, argument: "Incorrect, try again.")
        isWrong = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isWrong    = false
            userInput  = ""
            problem    = MathProblem.generate()
        }
    }
}

// MARK: - NumberPad

struct NumberPad: View {
    @Binding var input: String
    let onSubmit: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["⌫", "0", "✓"],
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        NumberKey(label: key) { tap(key) }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !input.isEmpty { input.removeLast() }
        case "✓":
            onSubmit()
        default:
            if input.count < 6 { input += key }
        }
    }
}

struct NumberKey: View {
    let label:  String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
    }

    private var accessibilityName: String {
        switch label {
        case "⌫": return "Delete"
        case "✓": return "Submit answer"
        default:  return label
        }
    }
}

// MARK: - Shake modifier

struct ShakeModifier: ViewModifier {
    let active: Bool
    var reduceMotion: Bool = false
    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .onChange(of: active) { _, isActive in
                guard isActive, !reduceMotion else { return }
                let steps: [(Double, CGFloat)] = [
                    (0.00, 10), (0.10, -10), (0.20, 8), (0.30, 0),
                ]
                for (delay, value) in steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.linear(duration: 0.08)) { offsetX = value }
                    }
                }
            }
    }
}
