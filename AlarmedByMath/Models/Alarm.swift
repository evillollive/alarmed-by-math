import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var hour: Int
    var minute: Int
    /// Weekday numbers matching Calendar convention: 1 = Sunday … 7 = Saturday
    var repeatDays:   Set<Int>
    var isEnabled:    Bool
    var difficulty:        Difficulty
    var problemCount:      Int
    /// Persistent ID from the user's music library. Stored as a String for plist compatibility.
    var songPersistentID:  String?
    /// Display name shown in the alarm form (artist – title).
    var songTitle:         String?
    /// Playback volume 0.1–1.0. Applied to AVAudioPlayer; system sounds ignore this.
    var volume:            Float
    /// How long in minutes before the alarm re-rings after the math challenge opens.
    var snoozeDuration:    Int
    /// When true the alarm sound keeps playing during the math challenge.
    var keepRinging:       Bool
    /// Tracks whether a one-time alarm has already fired and should no longer repeat.
    var hasFired:          Bool

    init(
        id:               UUID       = UUID(),
        label:            String     = "",
        hour:             Int        = 8,
        minute:           Int        = 0,
        repeatDays:       Set<Int>   = [],
        isEnabled:        Bool       = true,
        difficulty:       Difficulty = .medium,
        problemCount:     Int        = 1,
        songPersistentID: String?    = nil,
        songTitle:        String?    = nil,
        volume:           Float      = 1.0,
        snoozeDuration:   Int        = 5,
        keepRinging:      Bool       = false,
        hasFired:         Bool       = false
    ) {
        self.id               = id
        self.label            = label
        self.hour             = hour
        self.minute           = minute
        self.repeatDays       = repeatDays
        self.isEnabled        = isEnabled
        self.difficulty       = difficulty
        self.problemCount     = problemCount
        self.songPersistentID = songPersistentID
        self.songTitle        = songTitle
        self.volume           = volume
        self.snoozeDuration   = snoozeDuration
        self.keepRinging      = keepRinging
        self.hasFired         = hasFired
    }

    // MARK: - Custom Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, label, hour, minute, repeatDays, isEnabled, difficulty, problemCount
        case songPersistentID, songTitle, volume, snoozeDuration, keepRinging, hasFired
    }

    init(from decoder: Decoder) throws {
        let c             = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,      forKey: .id)
        label            = try c.decode(String.self,    forKey: .label)
        hour             = try c.decode(Int.self,       forKey: .hour)
        minute           = try c.decode(Int.self,       forKey: .minute)
        repeatDays       = try c.decode(Set<Int>.self,  forKey: .repeatDays)
        isEnabled        = try c.decode(Bool.self,      forKey: .isEnabled)
        difficulty       = try c.decodeIfPresent(Difficulty.self, forKey: .difficulty)      ?? .medium
        problemCount     = try c.decodeIfPresent(Int.self,        forKey: .problemCount)    ?? 1
        songPersistentID = try c.decodeIfPresent(String.self,     forKey: .songPersistentID)
        songTitle        = try c.decodeIfPresent(String.self,     forKey: .songTitle)
        volume           = try c.decodeIfPresent(Float.self,      forKey: .volume)          ?? 1.0
        snoozeDuration   = try c.decodeIfPresent(Int.self,        forKey: .snoozeDuration)  ?? 5
        keepRinging      = try c.decodeIfPresent(Bool.self,       forKey: .keepRinging)     ?? false
        hasFired         = try c.decodeIfPresent(Bool.self,       forKey: .hasFired)        ?? false
    }

    // MARK: - Computed

    /// Label to show on the alarm, falling back to a generic title.
    var displayLabel: String { label.isEmpty ? "Alarm" : label }

    /// Subtitle shown in the alarm list.
    var detailLabel: String {
        label.isEmpty ? repeatLabel : "\(label), \(repeatLabel)"
    }

    var timeString: String {
        formattedTime()
    }

    func formattedTime(locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        // This date represents a wall-clock time, not a scheduled occurrence.
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("jm")
        let time = Date(timeIntervalSinceReferenceDate: Double(hour * 3600 + minute * 60))
        return formatter.string(from: time)
    }

    var repeatLabel: String {
        formattedRepeatLabel()
    }

    func formattedRepeatLabel(calendar: Calendar = .autoupdatingCurrent) -> String {
        if repeatDays.isEmpty { return "Once" }
        let validDays = repeatDays.filter { (1...7).contains($0) }
        if validDays.count == 7 { return "Every day" }
        let labels = Self.orderedWeekdays(calendar: calendar)
            .filter { validDays.contains($0) }
            .map { calendar.shortWeekdaySymbols[$0 - 1] }
        return labels.isEmpty ? "Once" : labels.joined(separator: ", ")
    }

    static func orderedWeekdays(calendar: Calendar = .autoupdatingCurrent) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    func duplicateDraft() -> Alarm {
        Alarm(
            label: label,
            hour: hour,
            minute: minute,
            repeatDays: repeatDays,
            isEnabled: false,
            difficulty: difficulty,
            problemCount: problemCount,
            songPersistentID: songPersistentID,
            songTitle: songTitle,
            volume: volume,
            snoozeDuration: snoozeDuration,
            keepRinging: keepRinging
        )
    }

    func normalized() -> Alarm {
        var adjusted = self
        adjusted.label = adjusted.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if adjusted.label.count > 80 {
            adjusted.label = String(adjusted.label.prefix(80))
        }
        adjusted.hour = min(23, max(0, adjusted.hour))
        adjusted.minute = min(59, max(0, adjusted.minute))
        adjusted.repeatDays = Set(adjusted.repeatDays.filter { (1...7).contains($0) })
        adjusted.problemCount = min(10, max(1, adjusted.problemCount))
        adjusted.volume = min(1.0, max(0.1, adjusted.volume))
        adjusted.snoozeDuration = min(60, max(1, adjusted.snoozeDuration))
        if !adjusted.repeatDays.isEmpty {
            adjusted.hasFired = false
        }
        return adjusted
    }
}
