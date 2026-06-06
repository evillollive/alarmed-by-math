import SwiftUI

/// Presents a random math problem that the user must solve correctly to dismiss the alarm.
///
/// Behavior:
/// - The alarm follows the configured ring policy when this view appears:
///   either auto-snooze with a re-ring, or keep ringing while solving.
/// - A correct answer cancels the snoozed re-ring and fully dismisses the alarm.
/// - A wrong answer shakes the input field, generates a new problem, and lets the user try again.
struct MathChallengeView: View {
    @EnvironmentObject var scheduler:  AlarmScheduler
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var settings:   SettingsStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Active alarm looked up by ID.
    private var activeAlarm: Alarm? {
        guard
            let idString = scheduler.activeAlarmID,
            let uuid     = UUID(uuidString: idString)
        else { return nil }
        return alarmStore.alarms.first(where: { $0.id == uuid })
    }

    /// Effective difficulty resolved from the active alarm and the Whiz entitlement.
    private var effectiveDifficulty: Difficulty {
        Difficulty.effective(
            activeAlarm?.difficulty ?? .medium,
            whizUnlocked: settings.allowsWhizDifficulty
        )
    }
    private var problemCount: Int        { activeAlarm?.problemCount ?? 1 }

    @State private var problem        = MathProblem.generate() // replaced on appear
    @State private var userInput      = ""
    @State private var isWrong        = false
    @State private var hasSnoozed     = false
    @State private var showSuccess    = false
    @State private var solvedCount    = 0
    @State private var solveStartTime: Date? = nil
    /// Captured once when the challenge begins so a mid-solve entitlement refresh
    /// can't swap the keypad or difficulty out from under the user.
    @State private var challengeDifficulty: Difficulty = .medium
    @State private var hasStarted     = false

    var body: some View {
        ZStack {
            Theme.board.ignoresSafeArea()

            // Ruled chalkboard lines
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 44
                    var y: CGFloat = spacing
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(Theme.chalk.opacity(0.07), lineWidth: 1)
            }
            .ignoresSafeArea()

            VStack(spacing: 28) {
                header
                    .padding(.top, 48)

                Spacer()

                // Math expression
                VStack(spacing: 8) {
                    Text(subtitle)
                        .font(.system(.caption, design: Theme.fontDesign))
                        .foregroundColor(Theme.chalkFaded)

                    Text(problem.expression)
                        .font(.system(size: 54, weight: .bold, design: Theme.fontDesign))
                        .foregroundColor(Theme.chalkYellow)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal)
                }

                // Answer box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.boardDark.opacity(0.6))
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isWrong ? Theme.chalkRed : Theme.chalk.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                    Text(userInput.isEmpty ? "?" : userInput)
                        .font(.system(size: 40, weight: .medium, design: Theme.fontDesign))
                        .foregroundColor(userInput.isEmpty ? Theme.chalkFaded : Theme.chalk)
                }
                .frame(height: 72)
                .padding(.horizontal, 60)
                .modifier(ShakeModifier(active: isWrong))
                .accessibilityLabel("Answer")
                .accessibilityValue(userInput.isEmpty ? "No answer entered" : userInput)

                Spacer()

                // Input pad: scientific keypad for the Premium tier, integer pad otherwise.
                if challengeDifficulty == .whiz,
                   let scientificKeypad = PremiumPlugin.whiz?.keypad(input: $userInput, onSubmit: checkAnswer) {
                    scientificKeypad
                        .padding(.bottom, 24)
                } else {
                    NumberPad(input: $userInput, onSubmit: checkAnswer)
                        .padding(.bottom, 24)
                }
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear(perform: beginChallenge)
        .onDisappear {
            AppOrientation.reset()
            scheduler.stopSolveSoundtrack()
        }
        .onChange(of: showSuccess) { _, solved in
            guard solved else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                scheduler.dismiss()
                dismiss()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Text("Solve to Dismiss")
                .font(.system(.caption, design: Theme.fontDesign))
                .fontWeight(.semibold)
                .foregroundColor(Theme.chalkFaded)

            if hasSnoozed {
                Label(
                    "Alarm snoozed. Solve to fully dismiss",
                    systemImage: "moon.zzz.fill"
                )
                .font(.caption)
                .foregroundColor(Theme.chalkYellow)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Logic

    private var subtitle: String {
        if problemCount > 1 { return "Problem \(solvedCount + 1) of \(problemCount)" }
        return challengeDifficulty == .whiz ? "Round to 2 decimals" : "Solve for x"
    }

    private func beginChallenge() {
        if !hasStarted {
            hasStarted = true
            challengeDifficulty = effectiveDifficulty
            scheduler.startSolveSoundtrack(
                songPersistentID: activeAlarm?.songPersistentID,
                volume: activeAlarm?.volume ?? 1.0
            )
        }
        if challengeDifficulty == .whiz {
            AppOrientation.lock(.landscape, rotateTo: .landscapeRight)
        }
        snoozeIfNeeded()
    }

    private func snoozeIfNeeded() {
        guard !hasSnoozed else { return }
        hasSnoozed     = true
        solveStartTime = Date()
        problem        = MathProblem.generate(difficulty: challengeDifficulty)
        scheduler.snooze()
    }

    private func checkAnswer() {
        guard let entered = parsedInput(userInput) else {
            triggerWrong()
            return
        }
        if matches(entered, problem.answer) {
            StatsStore.shared.recordAttempt(difficulty: challengeDifficulty, correct: true)
            solvedCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if solvedCount >= problemCount {
                if let start = solveStartTime {
                    StatsStore.shared.recordSolveTime(Date().timeIntervalSince(start))
                }
                StatsStore.shared.recordAlarmDismissed()
                showSuccess = true
            } else {
                // More problems to go, reset input and generate next
                userInput = ""
                problem   = MathProblem.generate(difficulty: challengeDifficulty)
            }
        } else {
            StatsStore.shared.recordAttempt(difficulty: challengeDifficulty, correct: false)
            triggerWrong()
        }
    }

    /// Parse user input as a Double, tolerating a trailing decimal point and a lone sign.
    private func parsedInput(_ raw: String) -> Double? {
        var s = raw
        if s.hasSuffix(".") { s.removeLast() }
        if s.isEmpty || s == "-" { return nil }
        return Double(s)
    }

    /// Two values match when they agree to two decimal places.
    private func matches(_ a: Double, _ b: Double) -> Bool {
        guard a.isFinite, b.isFinite else { return false }
        return cents(a) == cents(b)
    }

    private func cents(_ value: Double) -> Int {
        Int((value * 100).rounded(.toNearestOrAwayFromZero))
    }

    private func triggerWrong() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        isWrong = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isWrong    = false
            userInput  = ""
            problem    = MathProblem.generate(difficulty: challengeDifficulty)
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
        ["+/-", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        NumberKey(label: key) { tap(key) }
                    }
                }
            }
            // Full-width submit button
            NumberKey(label: "✓") { tap("✓") }
        }
        .padding(.horizontal, 20)
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !input.isEmpty { input.removeLast() }
        case "✓":
            onSubmit()
        case "+/-":
            if input.isEmpty { return }
            if input.hasPrefix("-") {
                input = String(input.dropFirst())
            } else {
                input = "-" + input
            }
        default:
            // Max 6 digits; don't count the leading minus toward that limit
            let digitCount = input.hasPrefix("-") ? input.count - 1 : input.count
            if digitCount < 6 { input += key }
        }
    }
}

// MARK: - NumberKey

struct NumberKey: View {
    let label:  String
    let action: () -> Void

    var isSubmit: Bool { label == "✓" }
    var isDelete: Bool { label == "⌫" }
    var accessibilityLabel: String {
        switch label {
        case "✓": return "Submit answer"
        case "⌫": return "Delete"
        case "+/-": return "Toggle negative sign"
        default: return "Number \(label)"
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 28, weight: .regular, design: Theme.fontDesign))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .foregroundColor(
                    isSubmit ? Theme.boardDark :
                    isDelete ? Theme.chalkFaded : Theme.chalk
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSubmit ? Theme.chalkYellow : Theme.boardDark.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.chalk.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Shake modifier

struct ShakeModifier: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .onChange(of: active) { _, isActive in
                guard isActive else { return }
                guard !reduceMotion else { return }
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
