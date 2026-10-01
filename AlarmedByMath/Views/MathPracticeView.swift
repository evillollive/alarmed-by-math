import SwiftUI

struct MathPracticeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var difficulty: Difficulty = .medium
    @State private var problemCount = 1
    @State private var session: MathPracticeSession?

    var body: some View {
        ZStack {
            ChalkboardBackground()
            ScrollView {
                if let session {
                    PracticeRunView(session: session) { self.session = nil }
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    setup
                        .frame(maxWidth: 540)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                }
            }
            .id(session.map { _ in "practice-run" } ?? "practice-setup")
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Theme.chalkYellow)
                    .accessibilityIdentifier("practice.done")
            }
        }
        .onChange(of: settings.allowsWhizDifficulty) { _, unlocked in
            if !unlocked && difficulty == .whiz { difficulty = .expert }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 18) {
                ChalkClockMark()
                    .frame(width: 64, height: 64)
                Text("Meet the math.\nSkip the noise.")
                    .font(AppTypography.title)
                    .foregroundStyle(Theme.chalk)
            }
            Text("Try the real challenge keypad at your own pace. No alarm sound, no scheduled alarms, and no changes to your streak or statistics.")
                .font(AppTypography.body)
                .foregroundStyle(Theme.chalkFaded)

            VStack(alignment: .leading, spacing: 12) {
                Text("Difficulty")
                    .font(AppTypography.emphasis)
                    .foregroundStyle(Theme.chalkYellow)
                ForEach(Difficulty.allCases.filter { $0 != .whiz || settings.allowsWhizDifficulty }, id: \.self) { level in
                    Button {
                        difficulty = level
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level == .whiz ? "Whiz" : level.label)
                                    .font(AppTypography.emphasis)
                                    .foregroundStyle(Theme.chalk)
                                Text(description(for: level))
                                    .font(AppTypography.body)
                                    .foregroundStyle(Theme.chalkFaded)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: difficulty == level ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(difficulty == level ? Theme.chalkYellow : Theme.chalkFaded)
                        }
                        .frame(minHeight: 44)
                        .padding(16)
                        .background(Theme.boardDark, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(level.label) difficulty")
                    .accessibilityValue(difficulty == level ? "Selected" : "Not selected")
                    .accessibilityIdentifier("practice.difficulty.\(level.rawValue)")
                }
            }

            Stepper(value: $problemCount, in: 1...10) {
                Text("\(problemCount) problem\(problemCount == 1 ? "" : "s")")
                    .font(AppTypography.emphasis)
                    .foregroundStyle(Theme.chalk)
            }
            .padding(16)
            .background(Theme.boardDark, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("practice.problem-count")

            Button {
                session = MathPracticeSession(
                    difficulty: difficulty, problemCount: problemCount,
                    whizUnlocked: settings.allowsWhizDifficulty
                )
            } label: {
                Label("Start practice", systemImage: "function")
                    .font(AppTypography.emphasis)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Theme.boardDark)
                    .background(Theme.chalkYellow, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practice.start")
            Text("A scheduled alarm can still interrupt practice. You can leave practice at any time.")
                .font(AppTypography.body)
                .foregroundStyle(Theme.chalkFaded)
        }
    }

    private func description(for level: Difficulty) -> String {
        switch level {
        case .easy: return "Small-number addition."
        case .medium: return "Addition, subtraction, and multiplication."
        case .hard: return "Larger numbers and multiplication."
        case .expert: return "Negative answers, algebra, and fractions."
        case .whiz: return "Scientific problems. Round to two decimals."
        }
    }
}

private struct PracticeRunView: View {
    @State var session: MathPracticeSession
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Label("Silent practice", systemImage: "speaker.slash")
                .font(AppTypography.emphasis)
                .foregroundStyle(Theme.chalkFaded)
            Text(session.difficulty == .whiz ? "Whiz" : session.difficulty.label)
                .font(AppTypography.emphasis)
                .foregroundStyle(Theme.chalk)
            Text("Problem \(session.problemNumber) of \(session.problemCount)")
                .font(AppTypography.body)
                .foregroundStyle(Theme.chalkFaded)
                .accessibilityIdentifier("practice.progress")

            if session.phase != .completed {
                ChallengeProblemView(
                    problem: session.problem, input: session.input,
                    subtitle: session.difficulty == .whiz ? "Round to 2 decimals" : "Solve for the missing value",
                    isWrong: session.phase == .incorrect, identifierPrefix: "practice"
                )
            } else {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(Theme.chalkYellow)
                    .accessibilityHidden(true)
            }

            Text(session.feedback)
                .font(AppTypography.body)
                .foregroundStyle(session.phase == .incorrect ? Theme.chalkRed : Theme.chalk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("practice.feedback")

            if session.phase == .answering {
                ChallengeKeypad(difficulty: session.difficulty, input: $session.input) {
                    session.submit()
                    UIAccessibility.post(notification: .announcement, argument: session.feedback)
                }
            } else {
                Button {
                    if session.phase == .completed {
                        onRestart()
                    } else {
                        session.nextProblem()
                    }
                } label: {
                    Text(session.phase == .completed ? "Practice again" : session.phase == .incorrect ? "Try a fresh problem" : "Next problem")
                        .font(AppTypography.emphasis)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Theme.boardDark)
                        .background(Theme.chalkYellow, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .accessibilityIdentifier(session.phase == .completed ? "practice.again" : "practice.next")
            }
        }
    }
}
