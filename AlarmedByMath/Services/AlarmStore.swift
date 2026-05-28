import Foundation
import Combine

class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []

    private let storageKey = "saved_alarms"

    init() {
        load()
    }

    func add(_ alarm: Alarm) {
        alarms.append(alarm)
        save()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
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
        // Reset hasFired when re-enabling a one-time alarm
        if updated.isEnabled && updated.isOneTime {
            updated.hasFired = false
        }
        update(updated)
    }

    /// Marks a one-time alarm as fired so it won't be rescheduled.
    func markFired(_ alarm: Alarm) {
        guard alarm.isOneTime else { return }
        var updated = alarm
        updated.hasFired = true
        update(updated)
    }

    /// Finds an alarm by its UUID string.
    func alarm(forID idString: String) -> Alarm? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return alarms.first { $0.id == uuid }
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
        alarms = decoded
    }
}
