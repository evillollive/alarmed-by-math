import Foundation
import SwiftUI
import WidgetKit

/// App-side glue that derives the widget snapshot from the live stores and asks
/// WidgetKit to reload. Kept in the app target only (the widget never imports
/// this); the shared, primitive payload lives in `WidgetSharedStore`.
enum WidgetSync {
    /// Recompute the snapshot from the source-of-truth stores and reload the
    /// widget timelines. Safe to call often (scene activation, purchase/restore,
    /// alarm, theme, or streak changes).
    @MainActor
    static func refresh(alarmStore: AlarmStore, settings: SettingsStore, currentStreak: Int? = nil) {
        let snapshot = WidgetSharedStore.Snapshot(
            isPremiumUnlocked: settings.isWhizUnlocked,
            upcomingAlarms: upcomingAlarms(from: alarmStore.alarms),
            currentStreak: currentStreak ?? StatsStore.shared.stats.currentStreak,
            theme: palette(for: settings.activeTheme),
            config: config(from: settings)
        )

        WidgetSharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func upcomingAlarms(from alarms: [Alarm], now: Date = Date(), calendar: Calendar = .current) -> [WidgetSharedStore.UpcomingAlarm] {
        alarms.compactMap { alarm in
            guard let date = alarm.nextFireDate(after: now, calendar: calendar) else { return nil }
            return WidgetSharedStore.UpcomingAlarm(date: date, label: alarm.label, schedule: alarm.schedule)
        }
        .sorted { $0.date < $1.date }
    }

    private static func config(from settings: SettingsStore) -> WidgetSharedStore.WidgetConfig {
        WidgetSharedStore.WidgetConfig(
            clockStyle: settings.widgetClockStyle.rawValue,
            textSize: settings.widgetTextSize.rawValue,
            dateStyle: settings.widgetDateStyle.rawValue,
            upcomingCount: settings.widgetUpcomingCount,
            showStreak: settings.widgetShowStreak
        )
    }

    /// Flattens the user's chosen theme into primitive RGB + font so the widget
    /// can mirror it without sharing the app's Theme/Color code.
    private static func palette(for theme: AppTheme) -> WidgetSharedStore.ThemePalette {
        let colors = theme.colors
        return WidgetSharedStore.ThemePalette(
            board:       rgb(colors.boardSwatch),
            boardDark:   rgb(colors.boardDarkSwatch),
            chalk:       rgb(colors.chalkSwatch),
            chalkFaded:  rgb(colors.chalkFadedSwatch),
            chalkYellow: rgb(colors.chalkYellowSwatch),
            fontDesign:  designName(colors.fontDesign)
        )
    }

    private static func rgb(_ swatch: ThemeSwatch) -> WidgetSharedStore.ThemeRGB {
        WidgetSharedStore.ThemeRGB(r: swatch.red, g: swatch.green, b: swatch.blue)
    }

    private static func designName(_ design: Font.Design) -> String {
        switch design {
        case .serif:      return "serif"
        case .rounded:    return "rounded"
        case .monospaced: return "monospaced"
        default:          return "default"
        }
    }
}
