import Foundation

/// Small, dependency-free bridge between the app and the Home-screen widget.
///
/// This file is compiled into BOTH the app target and the widget extension, so
/// it must stay Foundation-only and never reference app types (SettingsStore,
/// AlarmStore, StoreKit, UIKit). The app is the source of truth: it derives
/// these primitive values and writes a snapshot; the widget only reads it.
enum WidgetSharedStore {
    /// App Group shared by the app and the widget extension. Must match the
    /// `com.apple.security.application-groups` entry in both entitlements files.
    static let appGroupID = "group.com.alarmedbymath.app"

    /// Custom URL the locked widget opens to bring the user to the paywall.
    static let paywallURL = URL(string: "alarmedbymath://paywall")!

    private static let snapshotKey = "widget.snapshot.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Everything the widget needs, kept deliberately primitive so it survives
    /// the app/extension boundary without shared model code.
    struct Snapshot: Codable, Equatable {
        var isPremiumUnlocked: Bool
        var nextAlarmDate: Date?
        var nextAlarmLabel: String
        var currentStreak: Int

        static let placeholder = Snapshot(
            isPremiumUnlocked: false,
            nextAlarmDate: nil,
            nextAlarmLabel: "",
            currentStreak: 0
        )
    }

    static func save(_ snapshot: Snapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> Snapshot {
        guard
            let defaults,
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}
