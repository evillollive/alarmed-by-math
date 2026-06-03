import Foundation
import Combine

class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []

    private let storageKey = "saved_alarms"
    private let nowProvider: () -> Date

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
        load()
    }

    func add(_ alarm: Alarm) {
        alarms.append(normalized(alarm))
        sortAlarms()
        expireOneTimeAlarms(reference: nowProvider())
        save()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = normalized(alarm, previous: alarms[index])
        sortAlarms()
        expireOneTimeAlarms(reference: nowProvider())
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
        if updated.isEnabled, updated.repeatDays.isEmpty {
            updated.hasFired = false
        }
        update(updated)
    }

    /// Returns the persisted, still-enabled alarm that should be scheduled after
    /// a save cycle, or `nil` if it is no longer valid to schedule. This makes the
    /// store the single source of truth for scheduling, including normalization
    /// and one-time expiration.
    func alarmForScheduling(id: UUID) -> Alarm? {
        guard let alarm = alarms.first(where: { $0.id == id }), alarm.isEnabled else {
            return nil
        }
        if alarm.repeatDays.isEmpty {
            guard !alarm.hasFired else { return nil }
            let now = nowProvider()
            guard let scheduled = Calendar.current.date(
                bySettingHour: alarm.hour,
                minute: alarm.minute,
                second: 0,
                of: now
            ), scheduled > now else {
                return nil
            }
        }
        return alarm
    }

    // MARK: - Next alarm

    /// Returns the next date any enabled alarm will fire, or nil if none are enabled.
    var nextAlarmDate: Date? {
        let now = nowProvider()
        let cal = Calendar.current

        return alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> Date? in
                var components        = DateComponents()
                components.hour       = alarm.hour
                components.minute     = alarm.minute
                components.second     = 0

                if alarm.repeatDays.isEmpty {
                    if alarm.hasFired { return nil }
                    guard let today = cal.date(
                        bySettingHour: alarm.hour,
                        minute: alarm.minute,
                        second: 0,
                        of: now
                    ) else { return nil }
                    return today > now ? today : nil
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
        alarms = decoded.map { normalized($0) }
        sortAlarms()
        expireOneTimeAlarms(reference: nowProvider())
        if alarms != decoded { save() }
    }

    func applyEntitlements() {
        let migrated = alarms.map { normalized($0) }
        guard migrated != alarms else {
            expireOneTimeAlarms(reference: nowProvider())
            return
        }
        alarms = migrated
        sortAlarms()
        expireOneTimeAlarms(reference: nowProvider())
        save()
    }

    /// Marks one-time alarms as fired once their scheduled time has passed.
    /// This prevents one-time alarms from auto-rescheduling to future days.
    func expireOneTimeAlarms(reference now: Date = Date(), excludingIDs: Set<UUID> = []) {
        var changed = false
        let cal = Calendar.current
        for index in alarms.indices {
            var alarm = alarms[index]
            guard alarm.isEnabled, alarm.repeatDays.isEmpty, !alarm.hasFired else { continue }
            if excludingIDs.contains(alarm.id) { continue }
            guard let scheduled = cal.date(
                bySettingHour: alarm.hour,
                minute: alarm.minute,
                second: 0,
                of: now
            ) else { continue }
            guard scheduled <= now else { continue }
            alarm.hasFired = true
            alarm.isEnabled = false
            alarms[index] = alarm
            changed = true
        }
        if changed {
            sortAlarms()
            save()
        }
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

    private func normalized(_ alarm: Alarm, previous: Alarm? = nil) -> Alarm {
        var adjusted = alarm.normalized()
        adjusted.difficulty = Difficulty.effective(
            adjusted.difficulty,
            whizUnlocked: SettingsStore.shared.allowsWhizDifficulty
        )
        if let previous, previous.repeatDays.isEmpty, adjusted.repeatDays.isEmpty {
            let timeChanged = previous.hour != adjusted.hour || previous.minute != adjusted.minute
            if adjusted.isEnabled && timeChanged {
                adjusted.hasFired = false
            }
        }
        return adjusted
    }
}
