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
        keepRinging:      Bool       = false
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
    }

    // MARK: - Custom Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, label, hour, minute, repeatDays, isEnabled, difficulty, problemCount
        case songPersistentID, songTitle, volume, snoozeDuration, keepRinging
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
    }

    // MARK: - Computed

    /// Label to show on the alarm, falling back to a generic title.
    var displayLabel: String { label.isEmpty ? "Alarm" : label }

    /// Subtitle shown in the alarm list.
    var detailLabel: String {
        label.isEmpty ? repeatLabel : "\(label), \(repeatLabel)"
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
