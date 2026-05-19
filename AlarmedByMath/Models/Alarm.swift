import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var hour: Int
    var minute: Int
    /// Weekday numbers matching Calendar convention: 1 = Sunday … 7 = Saturday
    var repeatDays: Set<Int>
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        label: String = "",
        hour: Int = 8,
        minute: Int = 0,
        repeatDays: Set<Int> = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
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
        return repeatDays.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}
