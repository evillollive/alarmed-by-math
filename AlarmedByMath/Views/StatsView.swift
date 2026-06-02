import SwiftUI

struct StatsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var alarmStore: AlarmStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Refresh stats whenever the view appears.
    @ObservedObject private var statsStore = StatsStore.shared

    private var stats: AppStats { statsStore.stats }
    private var visibleDifficulties: [Difficulty] {
        Difficulty.allCases.filter {
            settings.allowsWhizDifficulty || $0 != .whiz
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.board.ignoresSafeArea()

                // Ruled lines
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
                    .stroke(Theme.chalk.opacity(0.06), lineWidth: 1)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        summaryRow
                        accuracyCard
                        difficultyCard
                        if let easterEggState {
                            easterEggCard(easterEggState)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.boardDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                settings.activeTheme.colorScheme == .light ? .light : .dark,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.chalkYellow)
                        .fontWeight(.semibold)
                }
            }
        }
        .colorScheme(settings.activeTheme.colorScheme)
    }

    // MARK: - Summary row (3 cards)

    private var summaryRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    value: "\(stats.currentStreak)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    iconColor: Theme.chalkRed
                )
                StatCard(
                    value: "\(stats.totalAlarmsCompleted)",
                    label: "Dismissed",
                    icon: "checkmark.circle.fill",
                    iconColor: Theme.chalkBlue
                )
            }
            HStack(spacing: 12) {
                StatCard(
                    value: "\(stats.totalProblemsSolved)",
                    label: "Solved",
                    icon: "function",
                    iconColor: Theme.chalkYellow
                )
                StatCard(
                    value: "\(stats.totalSnoozesTaken)",
                    label: "Snoozes",
                    icon: "moon.zzz.fill",
                    iconColor: Theme.chalkFaded
                )
            }
        }
    }

    // MARK: - Overall accuracy card

    private var accuracyCard: some View {
        statsCard {
            VStack(spacing: 16) {
                sectionHeader("Overall Accuracy")

                if let pct = stats.overallAccuracy {
                    VStack(spacing: 6) {
                        Text(String(format: "%.0f%%", pct * 100))
                            .font(.system(size: 64, weight: .thin, design: Theme.fontDesign))
                            .foregroundColor(accuracyColor(pct))

                        AccuracyBar(value: pct, color: accuracyColor(pct))
                            .frame(height: 10)

                        Text("\(correctTotal) correct out of \(stats.totalAttempts) attempts")
                            .font(.caption)
                            .foregroundColor(Theme.chalkFaded)
                    }
                } else {
                    emptyHint("No attempts recorded yet")
                }

                if let best = stats.fastestSolveTime {
                    Divider()
                        .background(Theme.chalk.opacity(0.15))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best Solve Time")
                                .font(.system(.caption2, design: Theme.fontDesign))
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.chalkFaded)
                            Text(formatTime(best))
                                .font(.system(size: 32, weight: .light, design: Theme.fontDesign))
                                .foregroundColor(Theme.chalkYellow)
                        }
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .font(.title)
                            .foregroundColor(Theme.chalkYellow.opacity(0.7))
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total < 60 {
            return "\(total)s"
        }
        return "\(total / 60)m \(total % 60)s"
    }

    // MARK: - Per-difficulty card

    private var difficultyCard: some View {
        statsCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("By Difficulty")

                ForEach(visibleDifficulties, id: \.self) { level in
                    DifficultyRow(difficulty: level, stats: stats)
                }
            }
        }
    }

    // MARK: - Helpers

    private var correctTotal: Int {
        statsStore.stats.correctByDifficulty.values.reduce(0, +)
    }

    private var easterEggState: PythagorasEasterEggState? {
        PythagorasEasterEggState(
            alarmCount: alarmStore.alarms.count,
            dismissedCount: stats.totalAlarmsCompleted
        )
    }

    @ViewBuilder
    private func easterEggCard(_ easterEgg: PythagorasEasterEggState) -> some View {
        statsCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    PythagorasBadgeView(reduceMotion: reduceMotion)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Little Theorem")
                        Text(easterEgg.title)
                            .font(.system(.title3, design: Theme.fontDesign))
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.chalk)
                        Text(easterEgg.message)
                            .font(.subheadline)
                            .foregroundColor(Theme.chalkFaded)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()
                    .background(Theme.chalk.opacity(0.15))

                Text(easterEgg.footnote)
                    .font(.caption)
                    .foregroundColor(Theme.chalkBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(easterEgg.accessibilityLabel)
        }
    }

    private func accuracyColor(_ value: Double) -> Color {
        if value >= 0.80 { return Theme.chalkBlue }
        if value >= 0.50 { return Theme.chalkYellow }
        return Theme.chalkRed
    }

    @ViewBuilder
    private func statsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.boardDark.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.chalk.opacity(0.25), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: Theme.fontDesign))
            .fontWeight(.semibold)
            .foregroundColor(Theme.chalkYellow)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(Theme.chalkFaded)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let value:     String
    let label:     String
    let icon:      String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(size: 32, weight: .light, design: Theme.fontDesign))
                .foregroundColor(Theme.chalk)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.system(.caption2, design: Theme.fontDesign))
                .foregroundColor(Theme.chalkFaded)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.boardDark.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.chalk.opacity(0.25), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
}

// MARK: - DifficultyRow

private struct DifficultyRow: View {
    let difficulty: Difficulty
    let stats:      AppStats

    private var attempts: Int { stats.attemptsByDifficulty[difficulty.rawValue] ?? 0 }
    private var correct:  Int { stats.correctByDifficulty[difficulty.rawValue]  ?? 0 }
    private var accuracy: Double? { stats.accuracy(for: difficulty) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(difficulty.label)
                    .font(.system(.subheadline, design: Theme.fontDesign))
                    .foregroundColor(Theme.chalk)

                Spacer()

                if let pct = accuracy {
                    Text(String(format: "%.0f%%", pct * 100))
                        .font(.system(.subheadline, design: Theme.fontDesign))
                        .foregroundColor(barColor)
                    Text("(\(correct)/\(attempts))")
                        .font(.caption)
                        .foregroundColor(Theme.chalkFaded)
                } else {
                    Text("Not yet")
                        .font(.subheadline)
                        .foregroundColor(Theme.chalkFaded)
                }
            }

            AccuracyBar(value: accuracy ?? 0, color: accuracy == nil ? Theme.chalk.opacity(0.15) : barColor)
                .frame(height: 8)
        }
    }

    private var barColor: Color {
        guard let pct = accuracy else { return Theme.chalkFaded }
        if pct >= 0.80 { return Theme.chalkBlue }
        if pct >= 0.50 { return Theme.chalkYellow }
        return Theme.chalkRed
    }
}

// MARK: - AccuracyBar

private struct AccuracyBar: View {
    let value: Double   // 0.0 – 1.0
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.chalk.opacity(0.12))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
    }
}

struct PythagorasEasterEggState: Equatable {
    let title: String
    let message: String
    let footnote: String

    init?(alarmCount: Int, dismissedCount: Int) {
        guard alarmCount >= 8 || dismissedCount >= 8 else { return nil }

        if alarmCount >= 8 {
            title = "Pythagoras Club"
            message = "Eight alarms on the board unlock your tiny theorem sticker: a cozy little 3-4-5 triangle hiding in your stats like a secret proof."
        } else {
            title = "Proof of Wakefulness"
            message = "Eight completed alarms unlock your tiny theorem sticker: a cozy little 3-4-5 triangle hiding in your stats like a secret proof."
        }

        footnote = "It's the classic Pythagorean triple, 3² + 4² = 5², basically a tiny Euclid-approved gold star for doing the math and getting up anyway."
    }

    var accessibilityLabel: String {
        "\(title). \(message) \(footnote)"
    }
}

private struct PythagorasBadgeView: View {
    let reduceMotion: Bool

    @State private var isFloating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.chalkYellow.opacity(0.10))
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.chalkYellow.opacity(0.35), lineWidth: 1.5)

            VStack(spacing: 8) {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 18, y: 58))
                        path.addLine(to: CGPoint(x: 18, y: 18))
                        path.addLine(to: CGPoint(x: 68, y: 58))
                        path.closeSubpath()
                    }
                    .stroke(
                        Theme.chalkYellow,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 86, height: 74)

                    Circle()
                        .fill(Theme.chalkBlue)
                        .frame(width: 10, height: 10)
                        .offset(x: -25, y: 20)
                    Circle()
                        .fill(Theme.chalkRed)
                        .frame(width: 10, height: 10)
                        .offset(x: -25, y: -20)
                    Circle()
                        .fill(Theme.chalk)
                        .frame(width: 10, height: 10)
                        .offset(x: 25, y: 20)
                }

                Text("3² + 4² = 5²")
                    .font(.system(.caption2, design: Theme.fontDesign))
                    .foregroundColor(Theme.chalk)
            }
            .padding(.vertical, 14)
        }
        .frame(width: 138, height: 122)
        .offset(y: reduceMotion ? 0 : (isFloating ? -3 : 3))
        .rotationEffect(.degrees(reduceMotion ? 0 : (isFloating ? -1.2 : 1.2)))
        .onAppear {
            guard !reduceMotion else { return }
            isFloating = true
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
            value: isFloating
        )
        .accessibilityHidden(true)
    }
}
