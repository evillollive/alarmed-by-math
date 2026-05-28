import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var hour: Int
    var minute: Int
    /// Weekday numbers matching Calendar convention: 1 = Sunday … 7 = Saturday
    var repeatDays: Set<Int>
    var isEnabled: Bool
    /// Tracks whether a one-time alarm has already fired to prevent rescheduling.
    var hasFired: Bool

    var isOneTime: Bool { repeatDays.isEmpty }

    init(
        id: UUID = UUID(),
        label: String = "",
        hour: Int = 8,
        minute: Int = 0,
        repeatDays: Set<Int> = [],
        isEnabled: Bool = true,
        hasFired: Bool = false
    ) {
        self.id = id
        self.label = label
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.repeatDays = repeatDays.filter { (1...7).contains($0) }
        self.isEnabled = isEnabled
        self.hasFired = hasFired
    }

    var timeString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, period)
    }

    var repeatLabel: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every day" }
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return repeatDays
            .filter { (1...7).contains($0) }
            .sorted()
            .map { symbols[$0 - 1] }
            .joined(separator: ", ")
    }

    /// Whether this alarm should be scheduled (enabled, and not an already-fired one-time alarm).
    var isSchedulable: Bool {
        isEnabled && !(isOneTime && hasFired)
    }
}
