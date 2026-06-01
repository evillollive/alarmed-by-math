import Foundation

// MARK: - AppStats model

struct AppStats: Codable {
    var totalAlarmsCompleted:  Int            = 0
    var totalProblemsSolved:   Int            = 0
    var totalSnoozesTaken:     Int            = 0
    /// Best (shortest) time in seconds from challenge view appearing to final correct answer.
    var fastestSolveTime:      TimeInterval?  = nil
    var correctByDifficulty:   [String: Int]  = [:]
    var attemptsByDifficulty:  [String: Int]  = [:]
    var currentStreak:         Int            = 0
    var lastDismissedDate:     Date?          = nil

    /// Record one answer submission (correct or wrong) for a given difficulty.
    mutating func record(difficulty: Difficulty, correct: Bool) {
        let key = difficulty.rawValue
        attemptsByDifficulty[key, default: 0] += 1
        if correct {
            correctByDifficulty[key, default: 0] += 1
            totalProblemsSolved += 1
        }
    }

    /// Accuracy 0–1 for a specific difficulty, or nil if no attempts yet.
    func accuracy(for difficulty: Difficulty) -> Double? {
        let key = difficulty.rawValue
        guard let attempts = attemptsByDifficulty[key], attempts > 0 else { return nil }
        let correct = correctByDifficulty[key] ?? 0
        return Double(correct) / Double(attempts)
    }

    /// Total attempts across all difficulties.
    var totalAttempts: Int {
        attemptsByDifficulty.values.reduce(0, +)
    }

    /// Overall accuracy 0–1, or nil if no attempts yet.
    var overallAccuracy: Double? {
        guard totalAttempts > 0 else { return nil }
        let correct = correctByDifficulty.values.reduce(0, +)
        return Double(correct) / Double(totalAttempts)
    }
}

// MARK: - StatsStore

/// Tracks usage statistics and persists them to UserDefaults.
/// Call `StatsStore.shared` from anywhere in the app.
class StatsStore: ObservableObject {

    static let shared = StatsStore()

    @Published private(set) var stats = AppStats()

    private let storageKey = "app_stats_v1"

    init() {
        load()
    }

    // MARK: - Public recording methods

    /// Call this every time the user submits an answer (right or wrong).
    func recordAttempt(difficulty: Difficulty, correct: Bool) {
        stats.record(difficulty: difficulty, correct: correct)
        save()
    }

    /// Call this when the user finishes all problems. Updates best time if it's a new record.
    func recordSolveTime(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        if let best = stats.fastestSolveTime {
            if seconds < best { stats.fastestSolveTime = seconds }
        } else {
            stats.fastestSolveTime = seconds
        }
        save()
    }

    /// Call this every time the alarm is snoozed (math challenge view opens).
    func recordSnooze() {
        stats.totalSnoozesTaken += 1
        save()
    }

    /// Call this when the user finishes all required problems and fully dismisses the alarm.
    func recordAlarmDismissed() {
        stats.totalAlarmsCompleted += 1
        updateStreak()
        save()
    }

    // MARK: - Streak logic

    private func updateStreak() {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let last = stats.lastDismissedDate {
            let lastDay = cal.startOfDay(for: last)
            let days    = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            switch days {
            case 0:  break                         // Same day — streak unchanged
            case 1:  stats.currentStreak += 1      // Consecutive day — extend streak
            default: stats.currentStreak = 1       // Gap — restart streak
            }
        } else {
            stats.currentStreak = 1                // First ever dismiss
        }

        stats.lastDismissedDate = Date()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(AppStats.self, from: data)
        else { return }
        stats = decoded
    }
}
