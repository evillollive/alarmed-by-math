import Foundation
import WidgetKit

/// App-side glue that derives the widget snapshot from the live stores and asks
/// WidgetKit to reload. Kept in the app target only (the widget never imports
/// this); the shared, primitive payload lives in `WidgetSharedStore`.
enum WidgetSync {
    /// Recompute the snapshot from the source-of-truth stores and reload the
    /// widget timelines. Safe to call often (scene activation, purchase/restore,
    /// alarm or entitlement changes).
    @MainActor
    static func refresh(alarmStore: AlarmStore, settings: SettingsStore) {
        // Pair each enabled alarm with its own next fire date using the same
        // helper the scheduler uses, then pick the earliest. This keeps the
        // label tied to the alarm that actually fires next, even when several
        // alarms share a time or use different repeat days.
        let next = alarmStore.alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> (Alarm, Date)? in
                guard let date = AlarmScheduler.nextFireDate(for: alarm) else { return nil }
                return (alarm, date)
            }
            .min(by: { $0.1 < $1.1 })

        let snapshot = WidgetSharedStore.Snapshot(
            isPremiumUnlocked: settings.isWhizUnlocked,
            nextAlarmDate: next?.1,
            nextAlarmLabel: next?.0.label ?? "",
            currentStreak: StatsStore.shared.stats.currentStreak
        )

        WidgetSharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
