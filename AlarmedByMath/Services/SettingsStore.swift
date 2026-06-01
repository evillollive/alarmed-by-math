import Foundation
import Combine

/// Stores user preferences and acts as the single source of truth for
/// active theme, alarm sound, and snooze duration.
///
/// `SettingsStore.shared` is used by `Theme` for color lookups so every
/// view automatically reflects the active theme when it re-renders.
class SettingsStore: ObservableObject {

    /// Singleton used by Theme for color lookups.
    static let shared = SettingsStore()

    @Published var activeTheme: AppTheme {
        didSet { UserDefaults.standard.set(activeTheme.rawValue, forKey: Keys.theme) }
    }

    @Published var alarmSound: AlarmSound {
        didSet { UserDefaults.standard.set(alarmSound.rawValue, forKey: Keys.sound) }
    }

    /// Snooze duration in minutes (how long before the alarm re-rings after the
    /// math challenge view is opened).
    @Published var snoozeDuration: Int {
        didSet { UserDefaults.standard.set(snoozeDuration, forKey: Keys.snooze) }
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let theme  = "settings_theme"
        static let sound  = "settings_sound"
        static let snooze = "settings_snooze"
    }

    // MARK: - Init

    init() {
        let themeRaw = UserDefaults.standard.string(forKey: Keys.theme) ?? ""
        activeTheme  = AppTheme(rawValue: themeRaw)   ?? .chalk

        let soundRaw = UserDefaults.standard.string(forKey: Keys.sound) ?? ""
        alarmSound   = AlarmSound(rawValue: soundRaw) ?? .chime

        let stored     = UserDefaults.standard.integer(forKey: Keys.snooze)
        snoozeDuration = stored > 0 ? stored : 5
    }
}
