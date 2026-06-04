import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox
import MediaPlayer

enum NotificationPermissionStatus: Equatable {
    case unknown
    case granted
    case denied
}

struct RingingAlarmContext: Equatable {
    let alarmID: String
    var songPersistentID: String?
    var volume: Float
    var snoozeDuration: Int
    var keepRinging: Bool
    var autoPresentMath: Bool
    var preview: Bool

    init(
        alarmID: String,
        songPersistentID: String? = nil,
        volume: Float = 1.0,
        snoozeDuration: Int = 5,
        keepRinging: Bool = false,
        autoPresentMath: Bool = false,
        preview: Bool = false
    ) {
        self.alarmID = alarmID
        self.songPersistentID = songPersistentID
        self.volume = volume
        self.snoozeDuration = snoozeDuration
        self.keepRinging = keepRinging
        self.autoPresentMath = autoPresentMath
        self.preview = preview
    }

    func merged(with newer: RingingAlarmContext) -> RingingAlarmContext {
        RingingAlarmContext(
            alarmID: alarmID,
            songPersistentID: newer.songPersistentID ?? songPersistentID,
            volume: newer.volume,
            snoozeDuration: newer.snoozeDuration,
            keepRinging: newer.keepRinging,
            autoPresentMath: autoPresentMath || newer.autoPresentMath,
            preview: preview || newer.preview
        )
    }
}

struct RingingAlarmQueue: Equatable {
    private(set) var active: RingingAlarmContext?
    private(set) var queued: [RingingAlarmContext] = []

    var activeAlarmID: String? { active?.alarmID }
    var isRinging: Bool { active != nil }
    var autoPresentMath: Bool { active?.autoPresentMath ?? false }

    mutating func push(_ context: RingingAlarmContext) -> Bool {
        if let active, active.alarmID == context.alarmID {
            self.active = active.merged(with: context)
            return true
        }
        if active == nil {
            active = context
            return true
        }
        if let index = queued.firstIndex(where: { $0.alarmID == context.alarmID }) {
            queued[index] = queued[index].merged(with: context)
        } else {
            queued.append(context)
        }
        return false
    }

    mutating func popCurrent() -> RingingAlarmContext? {
        guard !queued.isEmpty else {
            active = nil
            return nil
        }
        active = queued.removeFirst()
        return active
    }
}

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

    @Published private(set) var activeAlarmID: String?
    @Published private(set) var isRinging: Bool = false
    /// When true, the ringing UI should jump straight to the math challenge
    /// (used on iOS 26 when the app is opened from the alarm's secondary button).
    @Published private(set) var autoPresentMath: Bool = false
    @Published private(set) var notificationPermissionStatus: NotificationPermissionStatus = .unknown

    // MARK: - Constants

    static let alarmCategory = "ALARM_CATEGORY"
    static let solveActionID = "ALARM_SOLVE_ACTION"

    /// Chained-notification fallback tuning (iOS 17–25).
    private static let chainSpacing: TimeInterval = 30   // seconds between rings
    private static let chainBurst    = 24                // ~12 minutes of ringing
    private static let chainBudget   = 58                // stay under iOS's 64 limit

    private var useAlarmKit: Bool {
        if #available(iOS 26.1, *) { return true } else { return false }
    }

    var supportsPerAlarmVolume: Bool { !useAlarmKit }
    private var runtimeSupportsCustomSongs: Bool { false }
    var supportsCustomSongs: Bool {
        runtimeSupportsCustomSongs && SettingsStore.shared.allowsCustomSongs
    }

    // MARK: - Active alarm state (set when ringing starts)

    private var activeSnoozeDuration: Int    = 5
    private var activeVolume:         Float  = 1.0
    private var activeSongID:         String? = nil
    private var activeKeepRinging:    Bool   = false

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?
    private var fallbackTimer: Timer?
    private var previewPlayer: AVAudioPlayer?
    private var previewStopTimer: Timer?
    private var ringingQueue = RingingAlarmQueue()

    // MARK: - Init

    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerNotificationCategories(center: center)
        refreshPermissionStatus(center: center)
    }

    // MARK: - Permissions

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self.notificationPermissionStatus = granted ? .granted : .denied
                    completion(granted)
                }
            }
        // AlarmKit has its own authorization, requested lazily when scheduling.
    }

    func refreshPermissionStatus(center: UNUserNotificationCenter = .current()) {
        center.getNotificationSettings { settings in
            let mapped = Self.permissionState(for: settings.authorizationStatus)
            DispatchQueue.main.async {
                self.notificationPermissionStatus = mapped
            }
        }
    }

    static func permissionState(for status: UNAuthorizationStatus) -> NotificationPermissionStatus {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
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
        content.sound              = UNNotificationSound(named: UNNotificationSoundName(SettingsStore.shared.alarmSound.fileName))
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
    ///
    /// `now` is injectable so the time-of-day-sensitive scheduling logic can be
    /// tested deterministically; production callers use the default `Date()`.
    static func nextFireDate(for alarm: Alarm, now: Date = Date()) -> Date? {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.hour   = alarm.hour
        comps.minute = alarm.minute
        comps.second = 0

        if alarm.repeatDays.isEmpty {
            if alarm.hasFired { return nil }
            guard let scheduled = cal.date(
                bySettingHour: alarm.hour,
                minute: alarm.minute,
                second: 0,
                of: now
            ) else { return nil }
            return scheduled > now ? scheduled : nil
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
        keepRinging:      Bool    = false,
        autoPresentMath:  Bool    = false,
        preview:          Bool    = false
    ) {
        let context = RingingAlarmContext(
            alarmID: alarmID,
            songPersistentID: songPersistentID,
            volume: volume,
            snoozeDuration: snoozeDuration,
            keepRinging: keepRinging,
            autoPresentMath: autoPresentMath,
            preview: preview
        )
        let becameActive = ringingQueue.push(context)
        syncPublishedState()

        guard becameActive else { return }

        activeSongID         = context.songPersistentID
        activeVolume         = context.volume
        activeSnoozeDuration = context.snoozeDuration
        activeKeepRinging    = context.keepRinging

        if useAlarmKit && !preview {
            // AlarmKit owns the sound on iOS 26; don't double up with in-app
            // audio. A preview (the Settings "Test Alarm") is the exception:
            // no AlarmKit alarm is firing, so we must play in-app so the user
            // actually hears something, even with the silent switch on.
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
        let didActivate = enqueueForMathChallenge(alarmID: id)
        if didActivate {
            applyActiveContextState()
        }
        return true
    }

    /// Forces the math challenge whenever an AlarmKit alarm is still alerting
    /// while the app is frontmost, so the user can't reach the alarm list and
    /// silence a ringing alarm without solving. Returns true if presented.
    @discardableResult
    func presentMathIfActiveRing() -> Bool {
        guard #available(iOS 26.1, *) else { return false }
        let ids = AlarmKitScheduler.alertingOriginalIDs()
        guard !ids.isEmpty else { return false }

        var activated = false
        for id in ids {
            if enqueueForMathChallenge(alarmID: id) {
                activated = true
            }
        }
        if activated {
            applyActiveContextState()
        }
        return true
    }

    /// Applies the ring policy as soon as the user opens the math challenge.
    /// If keep-ringing is enabled, no snooze is scheduled.
    /// Otherwise, the active ring is replaced with a delayed re-ring.
    func snooze() {
        guard let alarmID = activeAlarmID else { return }
        guard Self.shouldScheduleSnooze(keepRinging: activeKeepRinging) else { return }
        StatsStore.shared.recordSnooze()

        if #available(iOS 26.1, *), useAlarmKit {
            Task { await AlarmKitScheduler.snooze(alarmID, minutes: activeSnoozeDuration) }
            return
        }

        if !activeKeepRinging { stopSound() }

        let content = UNMutableNotificationContent()
        content.title              = "Snoozed Alarm"
        content.body               = "Tap to solve a math problem and dismiss"
        content.sound              = UNNotificationSound(named: UNNotificationSoundName(SettingsStore.shared.alarmSound.fileName))
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

        _ = ringingQueue.popCurrent()
        syncPublishedState()
        applyActiveContextState()
    }

    private func enqueueForMathChallenge(alarmID: String) -> Bool {
        let context = RingingAlarmContext(
            alarmID: alarmID,
            snoozeDuration: AlarmGate.snoozeDuration(alarmID),
            autoPresentMath: true
        )
        let didActivate = ringingQueue.push(context)
        syncPublishedState()
        return didActivate
    }

    private func syncPublishedState() {
        activeAlarmID = ringingQueue.activeAlarmID
        isRinging = ringingQueue.isRinging
        autoPresentMath = ringingQueue.autoPresentMath
    }

    private func applyActiveContextState() {
        guard let context = ringingQueue.active else {
            activeSongID = nil
            activeVolume = 1.0
            activeSnoozeDuration = 5
            activeKeepRinging = false
            return
        }

        activeSongID = context.songPersistentID
        activeVolume = context.volume
        activeSnoozeDuration = context.snoozeDuration
        activeKeepRinging = context.keepRinging

        if useAlarmKit && !context.preview { return }
        if let uuid = UUID(uuidString: context.alarmID) {
            removeChainedByID(uuid)
        }
        playAlarmSound(songPersistentID: context.songPersistentID, volume: context.volume)
    }

    // MARK: - Audio (foreground only)

    /// Plays a single sound option once (capped at a few seconds) so users can
    /// audition each alarm tone from Settings. Uses `.playback` so it overrides
    /// the silent switch (but not the media volume level).
    func previewSound(_ sound: AlarmSound) {
        previewStopTimer?.invalidate()
        previewPlayer?.stop()

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("Audio session setup failed: \(error)")
        }

        if sound.vibrates { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }

        guard let url = Bundle.main.url(
            forResource: sound.resource.name, withExtension: sound.resource.ext) else {
            AudioServicesPlaySystemSound(sound.systemSoundID)
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.volume        = 1.0
            player.play()
            previewPlayer = player
            previewStopTimer = Timer.scheduledTimer(
                withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.previewPlayer?.stop()
                self?.previewPlayer = nil
            }
        } catch {
            AudioServicesPlaySystemSound(sound.systemSoundID)
        }
    }

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

        let selected = SettingsStore.shared.alarmSound
        let url = Bundle.main.url(forResource: selected.resource.name, withExtension: selected.resource.ext)
               ?? Bundle.main.url(forResource: "alarm", withExtension: "caf")
               ?? Bundle.main.url(forResource: "alarm", withExtension: "wav")

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
        let autoPresentMath = response.actionIdentifier == Self.solveActionID
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        startRingingFromNotification(response.notification, autoPresentMath: autoPresentMath)
        completionHandler()
    }

    private func startRingingFromNotification(_ notification: UNNotification, autoPresentMath: Bool = false) {
        let info        = notification.request.content.userInfo
        let alarmID     = info["alarmID"] as? String ?? notification.request.identifier
        let songID      = info["songPersistentID"] as? String
        let volume      = (info["volume"] as? String).flatMap(Float.init) ?? 1.0
        let snoozeDur   = info["snoozeDuration"] as? Int ?? 5
        let keepRinging = info["keepRinging"] as? Bool ?? false
        DispatchQueue.main.async {
            self.startRinging(alarmID: alarmID, songPersistentID: songID,
                              volume: volume, snoozeDuration: snoozeDur, keepRinging: keepRinging,
                              autoPresentMath: autoPresentMath)
        }
    }

    // MARK: - Private helpers

    private func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
    }

    private func registerNotificationCategories(center: UNUserNotificationCenter) {
        let solveAction = UNNotificationAction(
            identifier: Self.solveActionID,
            title: "Solve to Dismiss",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.alarmCategory,
            actions: [solveAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    static func shouldScheduleSnooze(keepRinging: Bool) -> Bool {
        !keepRinging
    }
}
