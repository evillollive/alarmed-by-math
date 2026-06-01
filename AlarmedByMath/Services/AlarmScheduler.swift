import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox
import MediaPlayer

/// Manages alarm scheduling, in-app audio playback, and the ringing state.
///
/// Locked-screen behaviour depends on the OS:
/// - **iOS 26+**: alarms are handed to `AlarmKitScheduler`, which rings like the
///   system Clock app (sounds on the lock screen, breaks through silent mode and
///   Focus). The math gate is enforced there via re-ringing.
/// - **iOS 17–25**: AlarmKit does not exist, so we approximate a persistent
///   alarm by scheduling a *chain* of notifications a few seconds apart, each
///   playing the bundled sound, since a single notification only plays once and
///   app code cannot run while the device is locked.
class AlarmScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    // MARK: - Published state

    @Published var activeAlarmID: String?
    @Published var isRinging: Bool = false
    /// When true, the ringing UI should jump straight to the math challenge
    /// (used on iOS 26 when the app is opened from the alarm's secondary button).
    @Published var autoPresentMath: Bool = false

    // MARK: - Constants

    static let alarmCategory = "ALARM_CATEGORY"

    /// Bundled alarm tone. Must be < 30 seconds or iOS silently substitutes the
    /// default notification sound.
    private static let soundFile = "alarm.caf"

    /// Chained-notification fallback tuning (iOS 17–25).
    private static let chainSpacing: TimeInterval = 30   // seconds between rings
    private static let chainBurst    = 24                // ~12 minutes of ringing
    private static let chainBudget   = 58                // stay under iOS's 64 limit

    private var useAlarmKit: Bool {
        if #available(iOS 26.1, *) { return true } else { return false }
    }

    // MARK: - Active alarm state (set when ringing starts)

    private var activeSnoozeDuration: Int    = 5
    private var activeVolume:         Float  = 1.0
    private var activeSongID:         String? = nil
    private var activeKeepRinging:    Bool   = false

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?
    private var fallbackTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permissions

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        // AlarmKit has its own authorization, requested lazily when scheduling.
    }

    // MARK: - Scheduling

    /// Re-schedules all enabled alarms (call after store changes / on launch).
    func scheduleAlarms(_ alarms: [Alarm]) {
        if #available(iOS 26.1, *) {
            Task { await AlarmKitScheduler.scheduleAll(alarms) }
        } else {
            scheduleChainedAll(alarms)
        }
    }

    /// Schedules a single alarm.
    func schedule(_ alarm: Alarm) {
        if #available(iOS 26.1, *) {
            Task { await AlarmKitScheduler.schedule(alarm) }
        } else {
            scheduleChained(alarm)
        }
    }

    /// Removes all pending notifications / alarms for a given alarm.
    func cancel(_ alarm: Alarm) {
        if #available(iOS 26.1, *) {
            AlarmKitScheduler.cancel(alarm.id.uuidString)
        } else {
            removeChained(alarm)
        }
    }

    // MARK: - Chained notifications (iOS 17–25 fallback)

    private func scheduleChainedAll(_ alarms: [Alarm]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        // Nearest alarms get priority on the shared budget.
        let enabled = alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> (Alarm, Date)? in
                guard let next = Self.nextFireDate(for: alarm) else { return nil }
                return (alarm, next)
            }
            .sorted { $0.1 < $1.1 }

        var budget = Self.chainBudget
        for (alarm, next) in enabled {
            guard budget > 0 else { break }
            budget -= scheduleChain(for: alarm, firstFire: next, budget: budget)
        }
    }

    /// Convenience used by `schedule(_:)`; schedules just this alarm's chain
    /// against whatever notification budget remains after *other* alarms, so
    /// adding/editing several alarms can't push the total past iOS's 64-request
    /// cap (and can't drop this alarm entirely). A full, budget-balanced
    /// rebuild happens on the next app launch.
    private func scheduleChained(_ alarm: Alarm) {
        guard alarm.isEnabled, let next = Self.nextFireDate(for: alarm) else {
            removeChained(alarm); return
        }
        let prefix = alarm.id.uuidString
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            // This alarm's own chain is about to be replaced, so exclude it from
            // the count; budget against what other alarms have already claimed.
            let usedByOthers = pending.filter { !$0.identifier.hasPrefix(prefix) }.count
            let remaining = max(0, Self.chainBudget - usedByOthers)
            self.removeChained(alarm)
            guard remaining > 0 else { return }
            _ = self.scheduleChain(for: alarm, firstFire: next, budget: remaining)
        }
    }

    /// Schedules the notification chain for one alarm and returns how many
    /// notifications it consumed from the budget.
    @discardableResult
    private func scheduleChain(for alarm: Alarm, firstFire: Date, budget: Int) -> Int {
        var used = 0
        let cal = Calendar.current

        // Long-term recurrence: one repeating notification per selected weekday.
        if !alarm.repeatDays.isEmpty {
            for day in alarm.repeatDays.sorted() {
                guard used < budget else { return used }
                var comps = DateComponents()
                comps.hour    = alarm.hour
                comps.minute  = alarm.minute
                comps.weekday = day
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                add(makeChainRequest(alarm: alarm, identifier: "\(alarm.id.uuidString)-w\(day)", trigger: trigger))
                used += 1
            }
        }

        // Persistent burst for the soonest occurrence. For repeating alarms the
        // exact-time ring is already covered above, so start one spacing later.
        let startIndex = alarm.repeatDays.isEmpty ? 0 : 1
        for k in startIndex..<Self.chainBurst {
            guard used < budget else { break }
            let fire = firstFire.addingTimeInterval(Double(k) * Self.chainSpacing)
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            add(makeChainRequest(alarm: alarm, identifier: "\(alarm.id.uuidString)::\(k)", trigger: trigger))
            used += 1
        }
        return used
    }

    private func makeChainRequest(alarm: Alarm, identifier: String, trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title              = alarm.displayLabel
        content.body               = "Tap to solve a math problem and dismiss"
        content.sound              = UNNotificationSound(named: UNNotificationSoundName(Self.soundFile))
        content.interruptionLevel  = .timeSensitive
        content.categoryIdentifier = Self.alarmCategory
        var userInfo: [String: Any] = [
            "alarmID":        alarm.id.uuidString,
            "volume":         String(alarm.volume),
            "snoozeDuration": alarm.snoozeDuration,
            "keepRinging":    alarm.keepRinging
        ]
        if let songID = alarm.songPersistentID { userInfo["songPersistentID"] = songID }
        content.userInfo = userInfo
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func removeChained(_ alarm: Alarm) {
        var ids: [String] = ["\(alarm.id.uuidString)-snooze", alarm.id.uuidString]
        for day in 1...7 { ids.append("\(alarm.id.uuidString)-w\(day)") }
        for k in 0..<Self.chainBurst { ids.append("\(alarm.id.uuidString)::\(k)") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Computes the next time an alarm will fire, mirroring `AlarmStore`.
    static func nextFireDate(for alarm: Alarm) -> Date? {
        let now = Date()
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour   = alarm.hour
        comps.minute = alarm.minute
        comps.second = 0

        if alarm.repeatDays.isEmpty {
            return cal.nextDate(after: now.addingTimeInterval(-1), matching: comps, matchingPolicy: .nextTime)
        }
        return alarm.repeatDays.compactMap { weekday -> Date? in
            var c = comps
            c.weekday = weekday
            return cal.nextDate(after: now.addingTimeInterval(-1), matching: c, matchingPolicy: .nextTime)
        }.min()
    }

    // MARK: - Ringing state

    func startRinging(
        alarmID:          String,
        songPersistentID: String? = nil,
        volume:           Float   = 1.0,
        snoozeDuration:   Int     = 5,
        keepRinging:      Bool    = false
    ) {
        activeAlarmID        = alarmID
        activeSongID         = songPersistentID
        activeVolume         = volume
        activeSnoozeDuration = snoozeDuration
        activeKeepRinging    = keepRinging
        isRinging            = true

        if useAlarmKit {
            // AlarmKit owns the sound on iOS 26; don't double up with in-app audio.
            return
        }
        // Foreground ring: the queued chain is now redundant, cancel it so we
        // don't double-fire while the user is in the app.
        if let uuid = UUID(uuidString: alarmID) {
            removeChainedByID(uuid)
        }
        playAlarmSound(songPersistentID: songPersistentID, volume: volume)
    }

    private func removeChainedByID(_ id: UUID) {
        var ids: [String] = []
        for k in 0..<Self.chainBurst { ids.append("\(id.uuidString)::\(k)") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// On iOS 26 the app is opened straight into the math challenge for the
    /// alarm whose secondary button was tapped. Returns true if a challenge was
    /// presented.
    @discardableResult
    func presentMathIfPending() -> Bool {
        guard let id = AlarmGate.pendingMathAlarmID else { return false }
        AlarmGate.pendingMathAlarmID = nil
        activeAlarmID   = id
        autoPresentMath = true
        isRinging       = true
        return true
    }

    /// Forces the math challenge whenever an AlarmKit alarm is still alerting
    /// while the app is frontmost, so the user can't reach the alarm list and
    /// silence a ringing alarm without solving. Returns true if presented.
    @discardableResult
    func presentMathIfActiveRing() -> Bool {
        guard #available(iOS 26.1, *) else { return false }
        guard let id = AlarmKitScheduler.alertingOriginalID() else { return false }
        activeAlarmID   = id
        autoPresentMath = true
        isRinging       = true
        return true
    }

    /// Stops the in-app sound and schedules a re-ring notification. Called as
    /// soon as the user opens the math challenge view. No-op on iOS 26, where
    /// AlarmKit keeps ringing and the gate enforces solving.
    func snooze() {
        if useAlarmKit { return }
        guard let alarmID = activeAlarmID else { return }
        if !activeKeepRinging { stopSound() }
        StatsStore.shared.recordSnooze()

        let content = UNMutableNotificationContent()
        content.title              = "Snoozed Alarm"
        content.body               = "Tap to solve a math problem and dismiss"
        content.sound              = UNNotificationSound(named: UNNotificationSoundName(Self.soundFile))
        content.interruptionLevel  = .timeSensitive
        content.categoryIdentifier = Self.alarmCategory

        var userInfo: [String: Any] = [
            "alarmID":        alarmID,
            "volume":         String(activeVolume),
            "snoozeDuration": activeSnoozeDuration,
            "keepRinging":    activeKeepRinging
        ]
        if let songID = activeSongID { userInfo["songPersistentID"] = songID }
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(activeSnoozeDuration * 60), repeats: false)
        add(UNNotificationRequest(
            identifier: "\(alarmID)-snooze",
            content: content,
            trigger: trigger))
    }

    /// Clears ringing state once the user solves the math problem.
    func dismiss() {
        let alarmID = activeAlarmID
        stopSound()
        if #available(iOS 26.1, *) {
            if let alarmID { AlarmKitScheduler.solve(alarmID) }
        } else if let alarmID {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["\(alarmID)-snooze"])
        }
        activeAlarmID   = nil
        isRinging       = false
        autoPresentMath = false
    }

    // MARK: - Audio (foreground only)

    private func playAlarmSound(songPersistentID: String? = nil, volume: Float = 1.0) {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("Audio session setup failed: \(error)")
        }

        if let idString = songPersistentID,
           let persistentID = UInt64(idString) {
            let query = MPMediaQuery.songs()
            query.addFilterPredicate(MPMediaPropertyPredicate(
                value: NSNumber(value: persistentID),
                forProperty: MPMediaItemPropertyPersistentID
            ))
            if let item = query.items?.first, let assetURL = item.assetURL {
                do {
                    audioPlayer                = try AVAudioPlayer(contentsOf: assetURL)
                    audioPlayer?.numberOfLoops = -1
                    audioPlayer?.volume        = volume
                    audioPlayer?.play()
                    return
                } catch {
                    // Fall through to bundled sound below.
                }
            }
        }

        let url = Bundle.main.url(forResource: "alarm", withExtension: "caf")
               ?? Bundle.main.url(forResource: "alarm", withExtension: "wav")
               ?? Bundle.main.url(forResource: "alarm", withExtension: "mp3")

        guard let soundURL = url else {
            startFallbackLoop()
            return
        }

        do {
            audioPlayer                = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume        = volume
            audioPlayer?.play()
        } catch {
            startFallbackLoop()
        }
    }

    private func startFallbackLoop() {
        playFallbackOnce()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.playFallbackOnce()
        }
        if let timer = fallbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func playFallbackOnce() {
        let sound = SettingsStore.shared.alarmSound
        AudioServicesPlaySystemSound(sound.systemSoundID)
        if sound != .buzzOnly {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func stopSound() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        startRingingFromNotification(notification)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        startRingingFromNotification(response.notification)
        completionHandler()
    }

    private func startRingingFromNotification(_ notification: UNNotification) {
        let info        = notification.request.content.userInfo
        let alarmID     = info["alarmID"] as? String ?? notification.request.identifier
        let songID      = info["songPersistentID"] as? String
        let volume      = (info["volume"] as? String).flatMap(Float.init) ?? 1.0
        let snoozeDur   = info["snoozeDuration"] as? Int ?? 5
        let keepRinging = info["keepRinging"] as? Bool ?? false
        DispatchQueue.main.async {
            self.startRinging(alarmID: alarmID, songPersistentID: songID,
                              volume: volume, snoozeDuration: snoozeDur, keepRinging: keepRinging)
        }
    }

    // MARK: - Private helpers

    private func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
    }
}
