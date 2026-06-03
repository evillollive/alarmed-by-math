import Foundation
import Combine

class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []

    private let storageKey = "saved_alarms"

    init() {
        load()
    }

    func add(_ alarm: Alarm) {
        alarms.append(normalized(alarm))
        sortAlarms()
        save()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = normalized(alarm)
        sortAlarms()
        save()
    }

    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        save()
    }

    /// Flips `isEnabled` for the given alarm and persists the change.
    func toggle(_ alarm: Alarm) {
        var updated = alarm
        updated.isEnabled.toggle()
        update(updated)
    }

    // MARK: - Next alarm

    /// Returns the next date any enabled alarm will fire, or nil if none are enabled.
    var nextAlarmDate: Date? {
        let now = Date()
        let cal = Calendar.current

        return alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> Date? in
                var components        = DateComponents()
                components.hour       = alarm.hour
                components.minute     = alarm.minute
                components.second     = 0

                if alarm.repeatDays.isEmpty {
                    // One-time: fire today if still in the future, otherwise tomorrow
                    return cal.nextDate(
                        after: now.addingTimeInterval(-1),
                        matching: components,
                        matchingPolicy: .nextTime
                    )
                } else {
                    // Repeating: find the nearest matching weekday
                    return alarm.repeatDays.compactMap { weekday -> Date? in
                        var comps          = components
                        comps.weekday      = weekday
                        return cal.nextDate(
                            after: now.addingTimeInterval(-1),
                            matching: comps,
                            matchingPolicy: .nextTime
                        )
                    }.min()
                }
            }
            .min()
    }

    /// Human-readable countdown string, e.g. "in 6h 23m".
    var nextAlarmLabel: String? {
        guard let next = nextAlarmDate else { return nil }
        let interval     = next.timeIntervalSince(Date())
        guard interval > 0 else { return nil }
        let totalMinutes = Int(interval / 60)
        let days         = totalMinutes / (60 * 24)
        let hours        = (totalMinutes % (60 * 24)) / 60
        let minutes      = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "in \(days)d \(hours)h" : "in \(days)d"
        } else if hours > 0 {
            return minutes > 0 ? "in \(hours)h \(minutes)m" : "in \(hours)h"
        } else {
            return "in \(max(1, minutes))m"
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Alarm].self, from: data)
        else { return }
        alarms = decoded.map(normalized)
        sortAlarms()
        if alarms != decoded { save() }
    }

    func applyEntitlements() {
        let migrated = alarms.map(normalized)
        guard migrated != alarms else { return }
        alarms = migrated
        sortAlarms()
        save()
    }

    private func sortAlarms() {
        alarms.sort {
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            if $0.minute != $1.minute { return $0.minute < $1.minute }
            let labelOrder = $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel)
            if labelOrder != .orderedSame { return labelOrder == .orderedAscending }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func normalized(_ alarm: Alarm) -> Alarm {
        var adjusted = alarm
        adjusted.difficulty = Difficulty.effective(
            alarm.difficulty,
            whizUnlocked: SettingsStore.shared.allowsWhizDifficulty
        )
        return adjusted
    }
}
