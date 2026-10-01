import Foundation
import Combine

class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []

    private let storageKey = "saved_alarms"
    private let nowProvider: () -> Date
    private let calendarProvider: () -> Calendar
    private let defaults: UserDefaults

    init(
        nowProvider: @escaping () -> Date = Date.init,
        calendarProvider: @escaping () -> Calendar = { .current },
        defaults: UserDefaults = .standard
    ) {
        self.nowProvider = nowProvider
        self.calendarProvider = calendarProvider
        self.defaults = defaults
        load()
    }

    func add(_ alarm: Alarm) {
        var added = normalized(alarm)
        if added.isEnabled, added.repeatDays.isEmpty, !added.hasFired, added.oneTimeDay == nil {
            bindNextOneTimeDay(&added)
        }
        alarms.append(added)
        sortAlarms()
        expireOneTimeAlarms(reference: nowProvider())
        save()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        let previous = alarms[index]
        var updated = normalized(alarm)
        let scheduleChanged = updated.hour != previous.hour || updated.minute != previous.minute
            || !previous.repeatDays.isEmpty
        if updated.isEnabled, updated.repeatDays.isEmpty, !previous.isEnabled || scheduleChanged {
            updated.hasFired = false
            bindNextOneTimeDay(&updated)
        }
        alarms[index] = updated
        sortAlarms()
        expireOneTimeAlarms(reference: nowProvider())
        save()
    }

    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        save()
    }

    func toggle(_ alarm: Alarm) {
        var updated = alarm
        updated.isEnabled.toggle()
        if updated.isEnabled, updated.repeatDays.isEmpty { updated.hasFired = false }
        update(updated)
    }

    func markOneTimeAlarmFired(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }),
              alarms[index].repeatDays.isEmpty,
              !alarms[index].hasFired || alarms[index].isEnabled else { return }
        alarms[index].hasFired = true
        alarms[index].isEnabled = false
        save()
    }

    /// Scheduling always uses the persisted record, including its bound local day.
    func alarmForScheduling(id: UUID) -> Alarm? {
        guard let alarm = alarms.first(where: { $0.id == id }),
              alarm.nextFireDate(after: nowProvider(), calendar: calendarProvider()) != nil else { return nil }
        return alarm
    }

    var nextAlarmDate: Date? {
        let now = nowProvider()
        let calendar = calendarProvider()
        return alarms.compactMap { $0.nextFireDate(after: now, calendar: calendar) }.min()
    }

    var nextAlarmLabel: String? {
        let now = nowProvider()
        let calendar = calendarProvider()
        guard let next = alarms.compactMap({ $0.nextFireDate(after: now, calendar: calendar) }).min() else { return nil }
        let totalMinutes = max(1, Int(ceil(next.timeIntervalSince(now) / 60)))
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return hours > 0 ? "in \(days)d \(hours)h" : "in \(days)d"
        } else if hours > 0 {
            return minutes > 0 ? "in \(hours)h \(minutes)m" : "in \(hours)h"
        } else {
            return "in \(minutes)m"
        }
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(alarms), forKey: storageKey)
        } catch {
            print("Alarm persistence failed: \(error)")
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([Alarm].self, from: data)
            let today = AlarmDay(date: nowProvider(), calendar: calendarProvider())
            alarms = decoded.map {
                var migrated = normalized($0)
                if migrated.repeatDays.isEmpty, migrated.oneTimeDay == nil {
                    // Old records have no intended day. Preserve today's legacy
                    // interpretation rather than silently arming a missed alarm.
                    migrated.oneTimeDay = today
                }
                return migrated
            }
            sortAlarms()
            expireOneTimeAlarms(reference: nowProvider())
            if alarms != decoded { save() }
        } catch {
            print("Saved alarms could not be decoded: \(error)")
        }
    }

    func applyEntitlements(excludingIDs: Set<UUID> = []) {
        let migrated = alarms.map { normalized($0) }
        if migrated != alarms {
            alarms = migrated
            sortAlarms()
            save()
        }
        expireOneTimeAlarms(reference: nowProvider(), excludingIDs: excludingIDs)
    }

    func expireOneTimeAlarms(reference now: Date = Date(), excludingIDs: Set<UUID> = []) {
        var changed = false
        let calendar = calendarProvider()
        for index in alarms.indices {
            var alarm = alarms[index]
            guard alarm.isEnabled, alarm.repeatDays.isEmpty, !excludingIDs.contains(alarm.id) else { continue }
            guard alarm.hasFired || alarm.nextFireDate(after: now, calendar: calendar) == nil else { continue }
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

    private func bindNextOneTimeDay(_ alarm: inout Alarm) {
        alarm.oneTimeDay = AlarmSchedule.nextOneTimeDay(
            hour: alarm.hour, minute: alarm.minute, after: nowProvider(), calendar: calendarProvider()
        )
        if alarm.oneTimeDay == nil {
            alarm.isEnabled = false
            print("No valid upcoming local day could be found for alarm \(alarm.id).")
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

    private func normalized(_ alarm: Alarm) -> Alarm {
        var adjusted = alarm.normalized()
        adjusted.difficulty = Difficulty.effective(
            adjusted.difficulty, whizUnlocked: SettingsStore.shared.allowsWhizDifficulty
        )
        return adjusted
    }
}
