import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox

/// Manages alarm scheduling, in-app audio playback, and the ringing state.
///
/// Registered as the `UNUserNotificationCenterDelegate` so it can:
/// - Surface foreground notifications as a full-screen ringing UI.
/// - Handle notification taps that launch the app from the background.
class AlarmScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    // MARK: - Published state

    /// Queue of active alarm IDs (supports multiple simultaneous alarms).
    @Published var activeAlarmIDs: [String] = []
    @Published var isRinging: Bool = false
    @Published var notificationsAuthorized: Bool = true

    /// Convenience: the alarm currently being presented.
    var activeAlarmID: String? { activeAlarmIDs.first }

    // MARK: - Constants

    static let alarmCategory  = "ALARM_CATEGORY"
    /// How long the alarm is snoozed when the user starts the math challenge (seconds).
    static let snoozeInterval: TimeInterval = 5 * 60

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Init

    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Register notification category
        let category = UNNotificationCategory(
            identifier: Self.alarmCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Permissions

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self.notificationsAuthorized = granted
                    completion(granted)
                }
            }
    }

    /// Re-checks notification authorization status (call on foreground return).
    func refreshPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Scheduling helpers

    /// Re-schedules all schedulable alarms (call after store changes).
    func scheduleAlarms(_ alarms: [Alarm]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        alarms.filter(\.isSchedulable).forEach { schedule($0) }
    }

    /// Schedules local notification(s) for a single alarm.
    func schedule(_ alarm: Alarm) {
        guard alarm.isSchedulable else { return }

        let content = UNMutableNotificationContent()
        content.title            = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body             = "Solve a math problem to dismiss"
        content.sound            = .default
        content.categoryIdentifier = Self.alarmCategory
        content.userInfo         = ["alarmID": alarm.id.uuidString]

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

    func startRinging(alarmID: String) {
        if !activeAlarmIDs.contains(alarmID) {
            activeAlarmIDs.append(alarmID)
        }
        isRinging = true
        playAlarmSound()
    }

    /// Schedules a re-ring notification for the current alarm.
    /// Does NOT stop the sound — caller decides when to stop.
    func snooze() {
        guard let alarmID = activeAlarmID else { return }

        let content = UNMutableNotificationContent()
        content.title               = "Snoozed Alarm"
        content.body                = "Solve a math problem to dismiss"
        content.sound               = .default
        content.categoryIdentifier  = Self.alarmCategory
        content.userInfo            = ["alarmID": alarmID]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.snoozeInterval, repeats: false)
        add(UNNotificationRequest(
            identifier: "\(alarmID)-snooze",
            content: content,
            trigger: trigger))
    }

    /// Cancels the snooze notification and clears ringing state for the current alarm.
    /// Called when the user solves the math problem correctly.
    func dismiss() {
        guard let alarmID = activeAlarmID else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["\(alarmID)-snooze"])
        activeAlarmIDs.removeAll { $0 == alarmID }

        if activeAlarmIDs.isEmpty {
            stopSound()
            isRinging = false
        }
    }

    /// Stops all alarm sound and clears state entirely.
    func stopAll() {
        stopSound()
        activeAlarmIDs.removeAll()
        isRinging = false
    }

    // MARK: - Audio

    private func playAlarmSound() {
        guard audioPlayer == nil || audioPlayer?.isPlaying != true else { return }

        let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3")
               ?? Bundle.main.url(forResource: "alarm", withExtension: "wav")

        guard let soundURL = url else {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer              = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1  // loop indefinitely
            audioPlayer?.play()
        } catch {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func stopSound() {
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
        let alarmID = notification.request.content.userInfo["alarmID"] as? String
                    ?? notification.request.identifier
        DispatchQueue.main.async { self.startRinging(alarmID: alarmID) }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let alarmID = response.notification.request.content.userInfo["alarmID"] as? String
                    ?? response.notification.request.identifier
        DispatchQueue.main.async { self.startRinging(alarmID: alarmID) }
        completionHandler()
    }

    // MARK: - Private helpers

    private func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
    }
}
