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
    @State private var feedbackMessage = "Take a breath. You've got this."
    @State private var hasSnoozed     = false
    @State private var showSuccess    = false
    @State private var solvedCount    = 0
    @State private var solveStartTime: Date? = nil
    /// Captured once when the challenge begins so a mid-solve entitlement refresh
    /// can't swap the keypad or difficulty out from under the user.
    @State private var challengeDifficulty: Difficulty = .medium
    @State private var hasStarted     = false
    @State private var challengeAlarmID: String?

    var body: some View {
        ZStack {
            ChalkboardBackground()
            ScrollView {
                VStack(spacing: 24) {
                    header

                    ChallengeProblemView(
                        problem: problem, input: userInput, subtitle: subtitle,
                        isWrong: isWrong, identifierPrefix: "challenge"
                    )

                    Text(feedbackMessage)
                        .font(AppTypography.body)
                        .foregroundStyle(isWrong ? Theme.chalkRed : Theme.chalk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityIdentifier("challenge.feedback")

                    ChallengeKeypad(difficulty: challengeDifficulty, input: $userInput, onSubmit: checkAnswer)
                        .disabled(isWrong || showSuccess)
                }
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear(perform: beginChallenge)
        .onDisappear {
            AppOrientation.reset()
            if let challengeAlarmID {
                scheduler.stopSolveSoundtrack(for: challengeAlarmID)
            }
        }
        .onChange(of: showSuccess) { _, solved in
            guard solved else { return }
            let completedAlarmID = challengeAlarmID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard scheduler.activeAlarmID == completedAlarmID else { return }
                scheduler.dismiss()
                if !scheduler.autoPresentMath { dismiss() }
            }
        }
        .onChange(of: userInput) { _, input in
            if !input.isEmpty && !isWrong && !showSuccess {
                feedbackMessage = "Take a breath. You've got this."
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 12) {
            ChalkClockMark()
                .frame(width: 54, height: 54)
            Text("Solve to Dismiss")
                .font(AppTypography.title)
                .foregroundColor(Theme.chalk)

            if scheduler.isPreview {
                Text("Sound preview only. No alarm will be scheduled.")
                    .font(AppTypography.body)
                    .foregroundStyle(Theme.chalkFaded)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if hasSnoozed && !scheduler.keepsRingingWhileSolving {
                Label(
                    "Solve to fully dismiss the alarm",
                    systemImage: "moon.zzz.fill"
                )
                .font(AppTypography.body)
                .foregroundColor(Theme.chalkYellow)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            if let id = scheduler.activeAlarmID, let failure = scheduler.schedulingFailures[id] {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(AppTypography.body)
                    .foregroundStyle(Theme.chalkRed)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Logic

    private var subtitle: String {
        if problemCount > 1 { return "Problem \(min(solvedCount + 1, problemCount)) of \(problemCount)" }
        return challengeDifficulty == .whiz ? "Round to 2 decimals" : "Solve for x"
    }

    private func beginChallenge() {
        if !hasStarted {
            hasStarted = true
            challengeAlarmID = scheduler.activeAlarmID
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
        guard !isWrong && !showSuccess else { return }
        let result = problem.evaluateAnswer(userInput)
        guard result != .invalid else {
            triggerWrong()
            return
        }
        if result == .correct {
            if !scheduler.isPreview {
                StatsStore.shared.recordAttempt(difficulty: challengeDifficulty, correct: true)
            }
            solvedCount += 1
            UIAccessibility.post(notification: .announcement, argument: "Correct")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if solvedCount >= problemCount {
                if !scheduler.isPreview {
                    if let start = solveStartTime {
                        StatsStore.shared.recordSolveTime(Date().timeIntervalSince(start))
                    }
                    StatsStore.shared.recordAlarmDismissed()
                    if let id = challengeAlarmID.flatMap(UUID.init(uuidString:)) {
                        alarmStore.markOneTimeAlarmFired(id: id)
                    }
                }
                feedbackMessage = "Correct. You're all set."
                showSuccess = true
            } else {
                // More problems to go, reset input and generate next
                userInput = ""
                problem   = MathProblem.generate(difficulty: challengeDifficulty)
                feedbackMessage = "Correct. Next problem."
            }
        } else {
            if !scheduler.isPreview {
                StatsStore.shared.recordAttempt(difficulty: challengeDifficulty, correct: false)
            }
            triggerWrong()
        }
    }

    private func triggerWrong() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        UIAccessibility.post(notification: .announcement, argument: "Incorrect. Try a new problem.")
        feedbackMessage = "Not quite. Try a fresh problem."
        isWrong = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isWrong    = false
            userInput  = ""
            problem    = MathProblem.generate(difficulty: challengeDifficulty)
        }
    }
}

struct ChallengeProblemView: View {
    let problem: MathProblem
    let input: String
    let subtitle: String
    let isWrong: Bool
    let identifierPrefix: String

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(Theme.chalkFaded)
                Text(problem.expression)
                    .font(AppTypography.display)
                    .foregroundStyle(Theme.chalkYellow)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal)
                    .accessibilityIdentifier("\(identifierPrefix).expression")
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.boardDark.opacity(0.6))
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isWrong ? Theme.chalkRed : Theme.chalk.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                Text(input.isEmpty ? "?" : input)
                    .font(AppTypography.display)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(input.isEmpty ? Theme.chalkFaded : Theme.chalk)
            }
            .frame(minHeight: 76)
            .padding(.horizontal, 24)
            .modifier(ShakeModifier(active: isWrong))
            .accessibilityLabel("Answer")
            .accessibilityValue(input.isEmpty ? "No answer entered" : input)
        }
    }
}

struct ChallengeKeypad: View {
    let difficulty: Difficulty
    @Binding var input: String
    let onSubmit: () -> Void

    var body: some View {
        if difficulty == .whiz,
           let keypad = PremiumPlugin.whiz?.keypad(input: $input, onSubmit: onSubmit) {
            keypad
        } else {
            NumberPad(input: $input, onSubmit: onSubmit)
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
            Text(isSubmit ? "Check answer" : label)
                .font(isSubmit ? AppTypography.emphasis : AppTypography.title)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 4)
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
