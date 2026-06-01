import Foundation
import SwiftUI
import AppIntents
import AlarmKit

/// AlarmKit-backed scheduling (iOS 26+). AlarmKit alarms ring like the system
/// Clock app: they sound on the lock screen and break through the silent switch
/// and Focus. The app's "solve math to dismiss" gate is enforced by re-ringing
/// whenever the system Stop button is used without solving the problem.
@available(iOS 26.1, *)
enum AlarmKitScheduler {

    // MARK: - Authorization

    @discardableResult
    static func ensureAuthorized() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized: return true
        case .denied:     return false
        default:
            let state = try? await manager.requestAuthorization()
            return state == .authorized
        }
    }

    // MARK: - Scheduling

    /// Cancels everything AlarmKit knows about for these alarms and reschedules
    /// the enabled ones. Safe to call repeatedly (e.g. on every app launch).
    static func scheduleAll(_ alarms: [Alarm]) async {
        guard await ensureAuthorized() else { return }
        let alerting = alertingIDs()
        for alarm in alarms {
            let oid = alarm.id.uuidString
            // Never disturb an alarm that is actively ringing (or whose re-ring
            // is ringing): canceling it would silence the alarm and wipe the
            // math gate, letting the user escape without solving. These get
            // (re)scheduled the next time the app is opened while idle.
            if alerting.contains(oid) { continue }
            if AlarmGate.reringIDs(oid).contains(where: alerting.contains) { continue }
            cancel(oid)
            guard alarm.isEnabled else { continue }
            await schedulePrimary(alarm)
        }
    }

    /// UUID strings of every AlarmKit alarm currently in the alerting state.
    private static func alertingIDs() -> Set<String> {
        guard let current = try? AlarmManager.shared.alarms else { return [] }
        return Set(current.filter { $0.state == .alerting }.map { $0.id.uuidString })
    }

    /// App-level alarm id of any alarm that is currently alerting (primary or
    /// one of its re-rings), so the app can force the math gate when it comes
    /// to the foreground while an alarm is still ringing.
    static func alertingOriginalID() -> String? {
        guard let id = alertingIDs().first else { return nil }
        return AlarmGate.originalID(forRingingID: id)
    }

    static func schedule(_ alarm: Alarm) async {
        guard await ensureAuthorized() else { return }
        cancel(alarm.id.uuidString)
        guard alarm.isEnabled else { return }
        await schedulePrimary(alarm)
    }

    /// Schedules the recurring/one-time alarm whose AlarmKit id equals the
    /// app-level `Alarm.id`, so the gate maps cleanly back to it.
    private static func schedulePrimary(_ alarm: Alarm) async {
        let originalID = alarm.id.uuidString
        AlarmGate.reset(originalID)
        AlarmGate.clearReringIDs(originalID)
        AlarmGate.setLabel(originalID, alarm.displayLabel)
        let soundName = SettingsStore.shared.alarmSound.fileName
        AlarmGate.setSound(originalID, soundName)

        let schedule: AlarmKit.Alarm.Schedule = .relative(.init(
            time: .init(hour: alarm.hour, minute: alarm.minute),
            repeats: recurrence(for: alarm.repeatDays)
        ))
        let config = makeConfiguration(
            originalID:    originalID,
            ringingID:     originalID,
            label:         alarm.displayLabel,
            soundName:     soundName,
            schedule:      schedule
        )
        do {
            _ = try await AlarmManager.shared.schedule(
                id: alarm.id, configuration: config)
        } catch {
            print("AlarmKit schedule failed: \(error)")
        }
    }

    // MARK: - Re-ring (strict math gate)

    /// Back-off so we keep nagging without hammering the daemon: quick at first,
    /// then every 30s.
    static func reringDelay(forAttempt attempt: Int) -> TimeInterval {
        switch attempt {
        case ...2:  return 5
        case ...5:  return 15
        default:    return 30
        }
    }

    /// Schedules a brand-new one-shot alarm a few seconds out. A distinct id is
    /// used to avoid colliding with the alarm that is still being torn down.
    static func scheduleReRing(originalAlarmID: String, after delay: TimeInterval) async {
        guard await ensureAuthorized() else { return }
        let ringingID = UUID()
        AlarmGate.addReringID(originalAlarmID, ringingID.uuidString)

        let schedule: AlarmKit.Alarm.Schedule = .fixed(Date().addingTimeInterval(delay))
        let config = makeConfiguration(
            originalID:    originalAlarmID,
            ringingID:     ringingID.uuidString,
            label:         AlarmGate.label(originalAlarmID),
            soundName:     AlarmGate.sound(originalAlarmID),
            schedule:      schedule
        )
        do {
            _ = try await AlarmManager.shared.schedule(
                id: ringingID, configuration: config)
        } catch {
            print("AlarmKit re-ring failed: \(error)")
        }
    }

    // MARK: - Dismiss / cancel

    /// Marks the occurrence solved and silences the primary alarm plus every
    /// outstanding re-ring. Repeating alarms are stopped (which reschedules the
    /// next occurrence); one-shots and re-rings are removed.
    static func solve(_ originalID: String) {
        AlarmGate.markSolved(originalID)
        for rid in AlarmGate.reringIDs(originalID) {
            if let uuid = UUID(uuidString: rid) { stopOrCancel(uuid) }
        }
        AlarmGate.clearReringIDs(originalID)
        if let uuid = UUID(uuidString: originalID) { stopOrCancel(uuid) }
    }

    /// Fully removes the primary alarm and any re-rings (used when an alarm is
    /// disabled or deleted).
    static func cancel(_ originalID: String) {
        for rid in AlarmGate.reringIDs(originalID) {
            if let uuid = UUID(uuidString: rid) { try? AlarmManager.shared.cancel(id: uuid) }
        }
        AlarmGate.clearReringIDs(originalID)
        if let uuid = UUID(uuidString: originalID) { try? AlarmManager.shared.cancel(id: uuid) }
        AlarmGate.forget(originalID)
    }

    private static func stopOrCancel(_ id: UUID) {
        do { try AlarmManager.shared.stop(id: id) }
        catch { try? AlarmManager.shared.cancel(id: id) }
    }

    // MARK: - Builders

    private static func makeConfiguration(
        originalID: String,
        ringingID:  String,
        label:      String,
        soundName:  String,
        schedule:   AlarmKit.Alarm.Schedule
    ) -> AlarmManager.AlarmConfiguration<AlarmMathMetadata> {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: label),
            secondaryButton: AlarmButton(
                text: "Solve to Dismiss",
                textColor: .white,
                systemImageName: "function"
            ),
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: AlarmMathMetadata(originalAlarmID: originalID, label: label),
            tintColor: .red
        )
        return AlarmManager.AlarmConfiguration.alarm(
            schedule:        schedule,
            attributes:      attributes,
            stopIntent:      StopMathAlarmIntent(originalAlarmID: originalID, ringingAlarmID: ringingID),
            secondaryIntent: OpenMathChallengeIntent(originalAlarmID: originalID),
            sound:           .named(soundName)
        )
    }

    private static func recurrence(for days: Set<Int>) -> AlarmKit.Alarm.Schedule.Relative.Recurrence {
        guard !days.isEmpty else { return .never }
        // App stores Calendar weekday numbers (1 = Sunday … 7 = Saturday).
        let all: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday,
                                     .thursday, .friday, .saturday]
        let weekdays = days.sorted().compactMap { day -> Locale.Weekday? in
            (1...7).contains(day) ? all[day - 1] : nil
        }
        return .weekly(weekdays)
    }
}

// MARK: - Metadata

@available(iOS 26.1, *)
struct AlarmMathMetadata: AlarmMetadata {
    var originalAlarmID: String
    var label: String
}

// MARK: - App Intents

/// Runs when the user taps the system alarm's Stop button. If the math problem
/// has not been solved, it immediately re-rings so the alarm can't be escaped.
@available(iOS 26.1, *)
struct StopMathAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"

    @Parameter(title: "Original Alarm ID") var originalAlarmID: String
    @Parameter(title: "Ringing Alarm ID")  var ringingAlarmID: String

    init() {}
    init(originalAlarmID: String, ringingAlarmID: String) {
        self.originalAlarmID = originalAlarmID
        self.ringingAlarmID  = ringingAlarmID
    }

    func perform() async throws -> some IntentResult {
        let isPrimaryRing = (ringingAlarmID == originalAlarmID)
        if let uuid = UUID(uuidString: ringingAlarmID) {
            try? AlarmManager.shared.stop(id: uuid)
        }
        // AlarmKit reuses the primary id across every occurrence of a repeating
        // alarm, so a fresh primary ring must start a new gate cycle: clear the
        // previous occurrence's "solved" flag, re-ring counter, and re-ring ids.
        // Without this, solving once would disable the math gate forever.
        if isPrimaryRing {
            AlarmGate.reset(originalAlarmID)
            AlarmGate.clearReringIDs(originalAlarmID)
        }
        if !AlarmGate.isSolved(originalAlarmID) {
            let attempt = AlarmGate.incrementRerings(originalAlarmID)
            if attempt <= AlarmGate.maxRerings {
                await AlarmKitScheduler.scheduleReRing(
                    originalAlarmID: originalAlarmID,
                    after: AlarmKitScheduler.reringDelay(forAttempt: attempt))
            }
        }
        return .result()
    }
}

/// Runs when the user taps the alarm's "Solve to Dismiss" button. Opens the app
/// and records which alarm should show its math challenge.
@available(iOS 26.1, *)
struct OpenMathChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Solve to Dismiss"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Original Alarm ID") var originalAlarmID: String

    init() {}
    init(originalAlarmID: String) { self.originalAlarmID = originalAlarmID }

    func perform() async throws -> some IntentResult {
        AlarmGate.pendingMathAlarmID = originalAlarmID
        return .result()
    }
}
