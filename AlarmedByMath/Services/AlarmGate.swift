import Foundation

/// Shared, lightweight state used to enforce the "solve a math problem to
/// dismiss" gate across the app process and AlarmKit App Intents.
///
/// On iOS 26+ the alarm is driven by AlarmKit. When the system alarm fires on a
/// locked device, the only code that runs is the App Intent attached to the
/// alarm's Stop / secondary buttons. Those intents and the main app share this
/// `UserDefaults`-backed store so the app can tell whether a given alarm has
/// actually been dismissed by solving math, and so it can clean up every alarm
/// (the primary plus any automatic re-rings) once it has.
enum AlarmGate {
    private static let defaults = UserDefaults.standard

    /// Upper bound on automatic re-rings for a single occurrence so a user who
    /// genuinely cannot open the app is never trapped forever.
    static let maxRerings = 60

    private static func solvedKey(_ id: String)   -> String { "gate_solved_\(id)" }
    private static func ringIDsKey(_ id: String)  -> String { "gate_ringids_\(id)" }
    private static func reringKey(_ id: String)   -> String { "gate_rerings_\(id)" }
    private static func labelKey(_ id: String)    -> String { "gate_label_\(id)" }
    private static let pendingMathKey = "gate_pending_math"

    // MARK: - Solved flag (occurrence scoped)

    static func markSolved(_ originalID: String) {
        defaults.set(true, forKey: solvedKey(originalID))
    }

    static func isSolved(_ originalID: String) -> Bool {
        defaults.bool(forKey: solvedKey(originalID))
    }

    /// Clears the solved flag and re-ring counter for a fresh occurrence.
    /// Called every time the primary alarm is (re)scheduled.
    static func reset(_ originalID: String) {
        defaults.set(false, forKey: solvedKey(originalID))
        defaults.set(0, forKey: reringKey(originalID))
    }

    /// Removes every stored key for an alarm id (used when an alarm is deleted
    /// or disabled, and to keep tests from leaking state).
    static func forget(_ originalID: String) {
        defaults.removeObject(forKey: solvedKey(originalID))
        defaults.removeObject(forKey: ringIDsKey(originalID))
        defaults.removeObject(forKey: reringKey(originalID))
        defaults.removeObject(forKey: labelKey(originalID))
    }

    // MARK: - Active re-ring ids

    /// One-shot AlarmKit ids scheduled to re-ring after an un-solved Stop.
    static func reringIDs(_ originalID: String) -> [String] {
        defaults.stringArray(forKey: ringIDsKey(originalID)) ?? []
    }

    static func addReringID(_ originalID: String, _ id: String) {
        var ids = reringIDs(originalID)
        ids.append(id)
        defaults.set(ids, forKey: ringIDsKey(originalID))
    }

    static func clearReringIDs(_ originalID: String) {
        defaults.removeObject(forKey: ringIDsKey(originalID))
    }

    static func reringCount(_ originalID: String) -> Int {
        defaults.integer(forKey: reringKey(originalID))
    }

    @discardableResult
    static func incrementRerings(_ originalID: String) -> Int {
        let n = reringCount(originalID) + 1
        defaults.set(n, forKey: reringKey(originalID))
        return n
    }

    // MARK: - Label (needed to rebuild a re-ring off the main app)

    static func setLabel(_ originalID: String, _ label: String) {
        defaults.set(label, forKey: labelKey(originalID))
    }

    static func label(_ originalID: String) -> String {
        defaults.string(forKey: labelKey(originalID)) ?? "Alarm"
    }

    // MARK: - Pending math hand-off

    /// Set by the secondary "Solve to Dismiss" intent so the app knows which
    /// alarm to present the math challenge for when it is brought to the front.
    static var pendingMathAlarmID: String? {
        get { defaults.string(forKey: pendingMathKey) }
        set {
            if let value = newValue { defaults.set(value, forKey: pendingMathKey) }
            else { defaults.removeObject(forKey: pendingMathKey) }
        }
    }
}
