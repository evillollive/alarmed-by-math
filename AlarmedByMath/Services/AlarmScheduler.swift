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

enum AlarmPermissionError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Alarm access is off. Allow alarms in Settings, then retry scheduling."
    }
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
    @Published private(set) var alarmPermissionStatus: NotificationPermissionStatus = .unknown
    @Published private(set) var notificationSoundsEnabled = true
    @Published private(set) var schedulingFailures: [String: String] = [:]
    @Published private(set) var previewingSound: AlarmSound?
    @Published private(set) var previewErrorMessage: String?
    private var schedulingRevisions: [String: UUID] = [:]

    var permissionWarning: String? {
        Self.readinessWarning(
            usesAlarmKit: useAlarmKit,
            alarmPermission: alarmPermissionStatus,
            notificationPermission: notificationPermissionStatus,
            notificationSoundsEnabled: notificationSoundsEnabled
        )
    }

    var needsPermissionRequest: Bool {
        (useAlarmKit ? alarmPermissionStatus : notificationPermissionStatus) == .unknown
    }

    var schedulingFailureMessage: String? {
        guard !schedulingFailures.isEmpty else { return nil }
        return schedulingFailures.values.sorted().joined(separator: "\n")
    }

    static func readinessWarning(
        usesAlarmKit: Bool,
        alarmPermission: NotificationPermissionStatus,
        notificationPermission: NotificationPermissionStatus,
        notificationSoundsEnabled: Bool
    ) -> String? {
        let permission = usesAlarmKit ? alarmPermission : notificationPermission
        switch permission {
        case .unknown:
            return usesAlarmKit
                ? "Allow alarm access so scheduled alarms can ring, including while your phone is locked."
                : "Allow notifications and sounds so scheduled alarms can notify you."
        case .denied:
            return usesAlarmKit
                ? "Alarm access is off. Enable Alarms in Settings, then return here to reschedule."
                : "Notifications are off. Enable notifications and sounds in Settings."
        case .granted:
            if !usesAlarmKit && !notificationSoundsEnabled {
                return "Notification sounds are off. Enable Sounds in Settings to hear alarm notifications."
            }
            return nil
        }
    }

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
    var keepsRingingWhileSolving: Bool { activeKeepRinging }
    var isPreview: Bool { ringingQueue.active?.preview == true }

    /// iOS can't start music-library playback while the device is locked, so a
    /// custom song can't be the locked-screen wake sound. It plays in the
    /// foreground "solve the math" ringing screen once the alarm is opened,
    /// which the app always runs. That foreground path is available on every
    /// iOS version, so this is unconditionally `true`.
    private var runtimeSupportsCustomSongs: Bool { true }

    /// Whether a per-alarm custom solve-screen song can be chosen. Gated on the
    /// premium entitlement; the playback itself ships in the free binary.
    var supportsCustomSongs: Bool {
        runtimeSupportsCustomSongs && SettingsStore.shared.allowsCustomSongs
    }

    /// The song id that will actually be persisted/played for an alarm: the
    /// requested id when custom songs are available, otherwise `nil` so the
    /// alarm cleanly falls back to the bundled sound.
    func resolvedSongID(_ requested: String?) -> String? {
        supportsCustomSongs ? requested : nil
    }

    // MARK: - Active alarm state (set when ringing starts)

    private var activeSnoozeDuration: Int    = 5
    private var activeVolume:         Float  = 1.0
    private var activeSongID:         String? = nil
    private var activeKeepRinging:    Bool   = false

    // MARK: - Private

    private let audioSession: AudioSessionControlling
    private let makePlayer: (URL) throws -> any AlarmAudioPlaying
    private var audioPlayer: (any AlarmAudioPlaying)?
    private var soundtrackPlayer: (any AlarmAudioPlaying)?
    private var fallbackTimer: Timer?
    private var previewPlayer: (any AlarmAudioPlaying)?
    private var previewStopTimer: Timer?
    private var previewRequestID: UUID?
    private var alarmAudioRequestID: UUID?
    private var soundtrackRequestID: UUID?
    private var soundtrackAlarmID: String?
    private var audioRevision = UUID()
    private var ringingQueue = RingingAlarmQueue()

    // MARK: - Init

    override convenience init() {
        self.init(audioSession: AudioSessionController.shared)
    }

    init(
        audioSession: AudioSessionControlling,
        makePlayer: @escaping (URL) throws -> any AlarmAudioPlaying = { try AVAudioPlayer(contentsOf: $0) }
    ) {
        self.audioSession = audioSession
        self.makePlayer = makePlayer
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerNotificationCategories(center: center)
        refreshPermissionStatus(center: center)
    }

    deinit {
        previewStopTimer?.invalidate()
        fallbackTimer?.invalidate()
        previewPlayer?.stop()
        audioPlayer?.stop()
        soundtrackPlayer?.stop()
        if previewRequestID != nil || alarmAudioRequestID != nil || soundtrackRequestID != nil {
            audioSession.deactivate { result in
                if case .failure(let error) = result, !(error is CancellationError) {
                    print("Audio session cleanup failed: \(error)")
                }
            }
        }
    }

    // MARK: - Permissions

    func requestPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 26.1, *) {
            Task { @MainActor in
                do {
                    try await AlarmKitScheduler.ensureAuthorized()
                    alarmPermissionStatus = AlarmKitScheduler.permissionStatus
                    schedulingFailures.removeValue(forKey: "authorization")
                    completion(true)
                } catch {
                    alarmPermissionStatus = AlarmKitScheduler.permissionStatus
                    recordSchedulingFailure(error.localizedDescription, id: "authorization")
                    completion(false)
                }
            }
            return
        }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    self.notificationPermissionStatus = granted ? .granted : .denied
                    if let error {
                        self.recordSchedulingFailure(error.localizedDescription, id: "authorization")
                    } else {
                        self.schedulingFailures.removeValue(forKey: "authorization")
                    }
                    self.refreshPermissionStatus()
                    completion(granted)
                }
            }
    }

    func refreshPermissionStatus(center: UNUserNotificationCenter = .current()) {
        if #available(iOS 26.1, *) {
            alarmPermissionStatus = AlarmKitScheduler.permissionStatus
        }
        center.getNotificationSettings { settings in
            let mapped = Self.permissionState(for: settings.authorizationStatus)
            DispatchQueue.main.async {
                self.notificationPermissionStatus = mapped
                self.notificationSoundsEnabled = settings.soundSetting == .enabled
            }
        }
    }

    static func permissionState(for status: UNAuthorizationStatus) -> NotificationPermissionStatus {
        switch status {
        case .authorized, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined, .provisional:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    // MARK: - Scheduling

    /// Re-schedules all enabled alarms (call after store changes / on launch).
    func scheduleAlarms(_ alarms: [Alarm]) {
        if #available(iOS 26.1, *) {
            Task { @MainActor in
                let revision = UUID()
                for alarm in alarms { schedulingRevisions[alarm.id.uuidString] = revision }
                do {
                    let failures = try await AlarmKitScheduler.scheduleAll(alarms)
                    schedulingFailures.removeValue(forKey: "authorization")
                    for alarm in alarms where schedulingRevisions[alarm.id.uuidString] == revision {
                        schedulingFailures[alarm.id.uuidString] = failures[alarm.id]
                    }
                } catch {
                    for alarm in alarms where alarm.isEnabled && schedulingRevisions[alarm.id.uuidString] == revision {
                        recordSchedulingFailure("\(alarm.displayLabel): \(error.localizedDescription)",
                                                id: alarm.id.uuidString)
                    }
                }
                refreshPermissionStatus()
            }
        } else {
            schedulingFailures.removeAll()
            scheduleChainedAll(alarms)
        }
    }

    /// Schedules a single alarm.
    func schedule(_ alarm: Alarm) {
        if #available(iOS 26.1, *) {
            Task { @MainActor in
                let id = alarm.id.uuidString
                let revision = UUID()
                schedulingRevisions[id] = revision
                do {
                    try await AlarmKitScheduler.schedule(alarm)
                    if schedulingRevisions[id] == revision {
                        schedulingFailures.removeValue(forKey: id)
                        schedulingFailures.removeValue(forKey: "authorization")
                    }
                } catch {
                    if schedulingRevisions[id] == revision {
                        recordSchedulingFailure("\(alarm.displayLabel): \(error.localizedDescription)", id: id)
                    }
                }
                refreshPermissionStatus()
            }
        } else {
            schedulingFailures.removeValue(forKey: alarm.id.uuidString)
            scheduleChained(alarm)
        }
    }

    /// Removes all pending notifications / alarms for a given alarm.
    func cancel(_ alarm: Alarm) {
        schedulingRevisions.removeValue(forKey: alarm.id.uuidString)
        schedulingFailures.removeValue(forKey: alarm.id.uuidString)
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
            guard budget > 0 else {
                recordSchedulingFailure("\(alarm.displayLabel): notification capacity is full. Disable an unused alarm, then retry.",
                                        id: alarm.id.uuidString)
                continue
            }
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
            guard remaining > 0 else {
                DispatchQueue.main.async {
                    self.recordSchedulingFailure("\(alarm.displayLabel): notification capacity is full. Disable an unused alarm, then retry.",
                                                 id: prefix)
                }
                return
            }
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
                guard used < budget else {
                    DispatchQueue.main.async {
                        self.recordSchedulingFailure(
                            "\(alarm.displayLabel): not all repeat days could be scheduled. Disable an unused alarm, then retry.",
                            id: alarm.id.uuidString
                        )
                    }
                    return used
                }
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
        stopSoundPreview()

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
        playAlarmSound(volume: volume)
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
        if isPreview {
            if !activeKeepRinging {
                stopWakeAudio()
                deactivateAudioSessionIfIdle(alarmID: alarmID)
            }
            return
        }
        guard Self.shouldScheduleSnooze(keepRinging: activeKeepRinging) else { return }
        StatsStore.shared.recordSnooze()

        if #available(iOS 26.1, *), useAlarmKit {
            let minutes = activeSnoozeDuration
            Task { @MainActor in
                do {
                    try await AlarmKitScheduler.snooze(alarmID, minutes: minutes)
                } catch {
                    recordSchedulingFailure("The alarm could not be rescheduled after snoozing. \(error.localizedDescription)",
                                            id: alarmID)
                    refreshPermissionStatus()
                }
            }
            return
        }

        stopWakeAudio()
        deactivateAudioSessionIfIdle(alarmID: alarmID)

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
        if #available(iOS 26.1, *), !isPreview {
            if let alarmID { AlarmKitScheduler.solve(alarmID) }
        } else if let alarmID, !isPreview {
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
        stopSoundPreview()
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
        playAlarmSound(volume: context.volume)
    }

    // MARK: - Audio (foreground only)

    /// Auditions the bundled recording without changing the selected wake sound.
    func previewSound(_ sound: AlarmSound) {
        stopSoundPreview()
        previewErrorMessage = nil
        guard !isRinging else {
            previewErrorMessage = "Finish the active alarm before previewing another sound."
            return
        }
        guard let url = Bundle.main.url(
            forResource: sound.resource.name, withExtension: sound.resource.ext) else {
            previewErrorMessage = "\(sound.label) is missing from this installation."
            print("Missing alarm preview resource: \(sound.fileName)")
            return
        }

        do {
            let player = try makePlayer(url)
            guard player.duration > 0, player.duration < 30 else {
                previewErrorMessage = "\(sound.label) is not a valid alarm recording."
                print("Invalid alarm preview duration: \(sound.fileName), \(player.duration)")
                return
            }
            player.numberOfLoops = 0
            player.volume        = 1.0
            let requestID = UUID()
            previewRequestID = requestID
            audioRevision = requestID
            previewingSound = sound
            audioSession.activate(preparing: player) { [weak self] result in
                guard let self, self.previewRequestID == requestID, !self.isRinging else {
                    player.stop()
                    return
                }
                switch result {
                case .failure(let error):
                    player.stop()
                    self.stopSoundPreview()
                    self.previewErrorMessage = "Could not preview \(sound.label): \(error.localizedDescription)"
                    print("Alarm preview activation failed: \(error)")
                case .success:
                    guard player.play() else {
                        player.stop()
                        self.stopSoundPreview()
                        self.previewErrorMessage = "\(sound.label) could not start playing."
                        print("Alarm preview playback failed: \(sound.fileName)")
                        return
                    }
                    self.previewPlayer = player
                    if sound.vibrates { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
                    self.previewStopTimer = Timer.scheduledTimer(
                        withTimeInterval: player.duration + 0.05, repeats: false
                    ) { [weak self] _ in
                        guard self?.previewRequestID == requestID else { return }
                        self?.stopSoundPreview()
                    }
                }
            }
        } catch {
            stopSoundPreview()
            previewErrorMessage = "Could not preview \(sound.label): \(error.localizedDescription)"
            print("Alarm preview failed: \(error)")
        }
    }

    func stopSoundPreview() {
        let hadPreview = previewRequestID != nil || previewPlayer != nil
        previewRequestID = nil
        previewStopTimer?.invalidate()
        previewStopTimer = nil
        previewPlayer?.stop()
        previewPlayer = nil
        previewingSound = nil
        if hadPreview { deactivateAudioSessionIfIdle(preview: true) }
    }

    /// Plays the wake/alert sound. This is always the bundled sound chosen in
    /// Settings, on every iOS version. A custom song is never the wake sound
    /// (iOS can't start library playback while locked); it plays only as the
    /// in-app solve soundtrack via `startSolveSoundtrack`.
    private func playAlarmSound(volume: Float = 1.0) {
        stopWakeAudio()
        stopSoundtrackAudio()
        let requestID = UUID()
        let alarmID = activeAlarmID
        alarmAudioRequestID = requestID
        audioRevision = requestID
        let selected = SettingsStore.shared.alarmSound
        guard let soundURL = Bundle.main.url(forResource: selected.resource.name, withExtension: selected.resource.ext) else {
            recordSchedulingFailure("The selected alarm recording is missing. Trying the system fallback sound.",
                                    id: alarmID ?? "foreground-audio")
            startFallbackLoop()
            return
        }

        do {
            let player = try makePlayer(soundURL)
            player.numberOfLoops = -1
            player.volume = volume
            audioSession.activate(preparing: player) { [weak self] result in
                guard let self, self.alarmAudioRequestID == requestID,
                      self.activeAlarmID == alarmID, self.isRinging else {
                    player.stop()
                    return
                }
                switch result {
                case .failure(let error):
                    player.stop()
                    self.recordSchedulingFailure(
                        "Could not activate alarm audio. Trying the system fallback. \(error.localizedDescription)",
                        id: alarmID ?? "foreground-audio"
                    )
                    self.startFallbackLoop()
                case .success:
                    guard player.play() else {
                        player.stop()
                        self.recordSchedulingFailure("The alarm recording could not play. Trying the system fallback.",
                                                     id: alarmID ?? "foreground-audio")
                        self.startFallbackLoop()
                        return
                    }
                    self.audioPlayer = player
                }
            }
        } catch {
            recordSchedulingFailure("Could not load alarm audio. Trying the system fallback. \(error.localizedDescription)",
                                    id: alarmID ?? "foreground-audio")
            startFallbackLoop()
        }
    }

    private func startFallbackLoop() {
        fallbackTimer?.invalidate()
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
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func stopWakeAudio() {
        alarmAudioRequestID = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func stopSoundtrackAudio() {
        soundtrackRequestID = nil
        soundtrackAlarmID = nil
        soundtrackPlayer?.stop()
        soundtrackPlayer = nil
    }

    private func stopSound() {
        stopWakeAudio()
        stopSoundtrackAudio()
        deactivateAudioSessionIfIdle(alarmID: activeAlarmID)
    }

    private func deactivateAudioSessionIfIdle(preview: Bool = false, alarmID: String? = nil) {
        guard previewRequestID == nil, alarmAudioRequestID == nil, soundtrackRequestID == nil,
              previewPlayer == nil, audioPlayer == nil, soundtrackPlayer == nil, fallbackTimer == nil else { return }
        let revision = UUID()
        audioRevision = revision
        audioSession.deactivate { [weak self] result in
            guard case .failure(let error) = result else { return }
            guard !(error is CancellationError) else { return }
            print("Audio session deactivation failed: \(error)")
            guard let self, self.audioRevision == revision else { return }
            let message = "Could not release the audio session: \(error.localizedDescription)"
            if preview {
                self.previewErrorMessage = message
            } else {
                self.recordSchedulingFailure(message, id: alarmID ?? "foreground-audio")
            }
        }
    }

    // MARK: - Solve soundtrack (Premium)

    /// Plays the alarm's custom song as the foreground "solve" soundtrack, looping
    /// until `stopSolveSoundtrack()`. No-op unless custom songs are available
    /// (premium). Unavailable tracks report an error without silencing wake
    /// audio. The soundtrack replaces wake audio only after playback starts.
    func startSolveSoundtrack(songPersistentID: String?, volume: Float = 1.0) {
        guard supportsCustomSongs, let idString = songPersistentID,
              let alarmID = activeAlarmID else { return }
        guard let persistentID = UInt64(idString) else {
            recordSchedulingFailure("The selected solve soundtrack has an invalid library identifier.", id: alarmID)
            return
        }

        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: NSNumber(value: persistentID),
            forProperty: MPMediaItemPropertyPersistentID
        ))
        guard let item = query.items?.first, let assetURL = item.assetURL else {
            recordSchedulingFailure("The solve soundtrack is unavailable. Choose a downloaded, playable song.", id: alarmID)
            return
        }
        startSolveSoundtrack(assetURL: assetURL, alarmID: alarmID, volume: volume)
    }

    func startSolveSoundtrack(assetURL: URL, alarmID: String, volume: Float) {
        guard supportsCustomSongs, activeAlarmID == alarmID, isRinging else { return }
        do {
            let player = try makePlayer(assetURL)
            stopSoundtrackAudio()
            let requestID = UUID()
            soundtrackRequestID = requestID
            soundtrackAlarmID = alarmID
            audioRevision = requestID
            player.numberOfLoops = -1
            player.volume = volume
            audioSession.activate(preparing: player) { [weak self] result in
                guard let self, self.soundtrackRequestID == requestID,
                      self.activeAlarmID == alarmID, self.isRinging else {
                    player.stop()
                    return
                }
                switch result {
                case .failure(let error):
                    player.stop()
                    self.stopSoundtrackAudio()
                    self.recordSchedulingFailure("Could not activate the solve soundtrack: \(error.localizedDescription)", id: alarmID)
                    self.deactivateAudioSessionIfIdle(alarmID: alarmID)
                case .success:
                    guard player.play() else {
                        player.stop()
                        self.stopSoundtrackAudio()
                        self.recordSchedulingFailure("The solve soundtrack could not play.", id: alarmID)
                        self.deactivateAudioSessionIfIdle(alarmID: alarmID)
                        return
                    }
                    self.soundtrackPlayer = player
                    // Keep wake audio until the replacement actually starts.
                    self.stopWakeAudio()
                }
            }
        } catch {
            recordSchedulingFailure("Could not load the solve soundtrack: \(error.localizedDescription)", id: alarmID)
        }
    }

    /// Stops the solve soundtrack if it's playing. Safe to call when nothing is.
    func stopSolveSoundtrack(for alarmID: String? = nil) {
        if let alarmID, soundtrackAlarmID != alarmID { return }
        guard soundtrackRequestID != nil || soundtrackPlayer != nil else { return }
        let ownerID = soundtrackAlarmID
        stopSoundtrackAudio()
        deactivateAudioSessionIfIdle(alarmID: ownerID)
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
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.recordSchedulingFailure(
                    "\(request.content.title): \(error.localizedDescription)",
                    id: request.content.userInfo["alarmID"] as? String ?? request.identifier
                )
            }
        }
    }

    private func recordSchedulingFailure(_ message: String, id: String) {
        print("Alarm scheduling failed: \(message)")
        schedulingFailures[id] = message
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
