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

    private static let snapshotKey = "widget.snapshot.v2"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Everything the widget needs, kept deliberately primitive so it survives
    /// the app/extension boundary without shared model code.
    struct Snapshot: Codable, Equatable {
        var isPremiumUnlocked: Bool
        /// Soonest-first upcoming alarms (the app supplies a few; the widget
        /// shows as many as the user's layout preference and family allow).
        var upcomingAlarms: [UpcomingAlarm]
        var currentStreak: Int
        var theme: ThemePalette
        var config: WidgetConfig

        /// Convenience for the single soonest alarm (locked preview, summaries).
        var nextAlarm: UpcomingAlarm? { upcomingAlarms.first }

        static let placeholder = Snapshot(
            isPremiumUnlocked: false,
            upcomingAlarms: [],
            currentStreak: 0,
            theme: .placeholder,
            config: .placeholder
        )
    }

    /// One upcoming alarm, reduced to what the widget renders.
    struct UpcomingAlarm: Codable, Equatable {
        var date: Date
        var label: String
    }

    /// User-chosen widget layout, set in the app's premium settings and mirrored
    /// here so the extension can render without importing app types. Values are
    /// plain strings/ints so the contract stays stable across the boundary.
    struct WidgetConfig: Codable, Equatable {
        /// "digital" or "analog".
        var clockStyle: String
        /// "small", "medium", or "large".
        var textSize: String
        /// "off", "weekday", "short", or "full".
        var dateStyle: String
        /// How many upcoming alarms to list (1...3); the small family shows one.
        var upcomingCount: Int
        var showStreak: Bool

        /// How many upcoming alarms to keep in the snapshot. Larger than the max
        /// the UI lists (3) so that, as alarms pass during the timeline, the
        /// widget can still backfill later ones without an app refresh.
        static let snapshotBufferCount = 6

        static let placeholder = WidgetConfig(
            clockStyle: "digital",
            textSize: "medium",
            dateStyle: "weekday",
            upcomingCount: 1,
            showStreak: true
        )
    }

    /// A single RGB swatch, stored as components so the widget can rebuild a
    /// SwiftUI Color without sharing the app's Color/Theme code.
    struct ThemeRGB: Codable, Equatable {
        var r: Double
        var g: Double
        var b: Double
    }

    /// The resolved colors + font for the user's chosen theme. The app derives
    /// this from its theme table and writes it here, so the widget mirrors any
    /// current or future theme with no duplicated palette.
    struct ThemePalette: Codable, Equatable {
        var board: ThemeRGB
        var boardDark: ThemeRGB
        var chalk: ThemeRGB
        var chalkFaded: ThemeRGB
        var chalkYellow: ThemeRGB
        /// One of: "default", "serif", "rounded", "monospaced".
        var fontDesign: String

        /// Defaults to the Chalkboard theme so a first render before the app has
        /// written a snapshot still looks intentional.
        static let placeholder = ThemePalette(
            board:       ThemeRGB(r: 0.16, g: 0.30, b: 0.20),
            boardDark:   ThemeRGB(r: 0.10, g: 0.20, b: 0.13),
            chalk:       ThemeRGB(r: 0.96, g: 0.96, b: 0.92),
            chalkFaded:  ThemeRGB(r: 0.72, g: 0.74, b: 0.70),
            chalkYellow: ThemeRGB(r: 0.99, g: 0.89, b: 0.38),
            fontDesign:  "rounded"
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
