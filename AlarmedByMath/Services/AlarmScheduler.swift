import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox
import MediaPlayer

/// Manages alarm scheduling, in-app audio playback, and the ringing state.
///
/// Registered as the `UNUserNotificationCenterDelegate` so it can:
/// - Surface foreground notifications as a full-screen ringing UI.
/// - Handle notification taps that launch the app from the background.
class AlarmScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    // MARK: - Published state

    @Published var activeAlarmID: String?
    @Published var isRinging: Bool = false

    // MARK: - Constants

    static let alarmCategory = "ALARM_CATEGORY"

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
    }

    // MARK: - Scheduling helpers

    /// Re-schedules all enabled alarms (call after store changes).
    func scheduleAlarms(_ alarms: [Alarm]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        alarms.filter(\.isEnabled).forEach { schedule($0) }
    }

    /// Schedules local notification(s) for a single alarm.
    func schedule(_ alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title              = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body               = "Tap to solve a math problem and dismiss"
        content.sound              = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
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

        var components    = DateComponents()
        components.hour   = alarm.hour
        components.minute = alarm.minute

        if alarm.repeatDays.isEmpty {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components, repeats: false)
            add(UNNotificationRequest(
                identifier: alarm.id.uuidString,
                content: content,
                trigger: trigger))
        } else {
            for day in alarm.repeatDays {
                components.weekday = day
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components, repeats: true)
                add(UNNotificationRequest(
                    identifier: "\(alarm.id.uuidString)-\(day)",
                    content: content,
                    trigger: trigger))
            }
        }
    }

    /// Removes all pending notifications for a given alarm.
    func cancel(_ alarm: Alarm) {
        var ids = [alarm.id.uuidString]
        for day in 1...7 { ids.append("\(alarm.id.uuidString)-\(day)") }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
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
        playAlarmSound(songPersistentID: songPersistentID, volume: volume)
    }

    /// Stops the in-app sound and schedules a re-ring notification.
    /// Called as soon as the user opens the math challenge view.
    func snooze() {
        guard let alarmID = activeAlarmID else { return }
        // Only stop sound if keep-ringing is off; otherwise let it play through the challenge
        if !activeKeepRinging { stopSound() }
        StatsStore.shared.recordSnooze()

        let content = UNMutableNotificationContent()
        content.title              = "Snoozed Alarm"
        content.body               = "Tap to solve a math problem and dismiss"
        content.sound              = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.interruptionLevel  = .timeSensitive
        content.categoryIdentifier = Self.alarmCategory

        // Carry all per-alarm settings into the snooze notification
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

    /// Cancels the snooze notification and clears ringing state.
    /// Called when the user solves the math problem correctly.
    func dismiss() {
        guard let alarmID = activeAlarmID else { return }
        stopSound()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["\(alarmID)-snooze"])
        activeAlarmID = nil
        isRinging     = false
    }

    // MARK: - Audio

    private func playAlarmSound(songPersistentID: String? = nil, volume: Float = 1.0) {
        // Configure audio session to play over silent switch and on lock screen
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("Audio session setup failed: \(error)")
        }

        // Try the user's chosen song first
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
                    return  // Successfully playing the chosen song
                } catch {
                    // Fall through to default sound below
                }
            }
        }

        // Fall back to bundled alarm file
        let url = Bundle.main.url(forResource: "alarm", withExtension: "wav")
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

    /// Loops vibration + a built-in system alert tone until stopSound() is called.
    private func startFallbackLoop() {
        playFallbackOnce()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.playFallbackOnce()
        }
        // Ensure the timer fires even while scroll views are tracking
        if let timer = fallbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func playFallbackOnce() {
        let sound = SettingsStore.shared.alarmSound
        AudioServicesPlaySystemSound(sound.systemSoundID)
        // Always vibrate alongside the sound for maximum annoyance
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
        let info          = notification.request.content.userInfo
        let alarmID       = info["alarmID"] as? String ?? notification.request.identifier
        let songID        = info["songPersistentID"] as? String
        let volume        = (info["volume"] as? String).flatMap(Float.init) ?? 1.0
        let snoozeDur     = info["snoozeDuration"] as? Int ?? 5
        let keepRinging   = info["keepRinging"] as? Bool ?? false
        DispatchQueue.main.async {
            self.startRinging(alarmID: alarmID, songPersistentID: songID,
                              volume: volume, snoozeDuration: snoozeDur, keepRinging: keepRinging)
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info        = response.notification.request.content.userInfo
        let alarmID     = info["alarmID"] as? String ?? response.notification.request.identifier
        let songID      = info["songPersistentID"] as? String
        let volume      = (info["volume"] as? String).flatMap(Float.init) ?? 1.0
        let snoozeDur   = info["snoozeDuration"] as? Int ?? 5
        let keepRinging = info["keepRinging"] as? Bool ?? false
        DispatchQueue.main.async {
            self.startRinging(alarmID: alarmID, songPersistentID: songID,
                              volume: volume, snoozeDuration: snoozeDur, keepRinging: keepRinging)
        }
        completionHandler()
    }

    // MARK: - Private helpers

    private func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
    }
}
