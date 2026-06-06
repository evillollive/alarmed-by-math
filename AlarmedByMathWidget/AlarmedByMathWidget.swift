import WidgetKit
import SwiftUI

// MARK: - Timeline

struct AlarmEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSharedStore.Snapshot
}

struct AlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmEntry {
        AlarmEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        completion(AlarmEntry(date: Date(), snapshot: WidgetSharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        let snapshot = WidgetSharedStore.load()
        let entry = AlarmEntry(date: Date(), snapshot: snapshot)

        // Refresh shortly after the next alarm fires (so the widget moves on to
        // the following alarm), otherwise check back in an hour. The app also
        // pushes reloads on entitlement/alarm changes via WidgetCenter.
        let refresh: Date
        if let next = snapshot.nextAlarmDate, next > Date() {
            refresh = next.addingTimeInterval(60)
        } else {
            refresh = Date().addingTimeInterval(60 * 60)
        }

        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Widget

struct AlarmedByMathWidget: Widget {
    private let kind = "AlarmedByMathWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmProvider()) { entry in
            AlarmWidgetView(snapshot: entry.snapshot)
                .containerBackground(Theme.board, for: .widget)
        }
        .configurationDisplayName("Next Alarm")
        .description("See your next alarm and solve streak at a glance. Premium feature.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct AlarmWidgetView: View {
    let snapshot: WidgetSharedStore.Snapshot

    var body: some View {
        if snapshot.isPremiumUnlocked {
            UnlockedWidgetView(snapshot: snapshot)
        } else {
            LockedWidgetView()
        }
    }
}

private struct UnlockedWidgetView: View {
    let snapshot: WidgetSharedStore.Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Next Alarm", systemImage: "alarm.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.chalkFaded)

            if let next = snapshot.nextAlarmDate, next > Date() {
                Text(next, style: .time)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.chalk)
                if !snapshot.nextAlarmLabel.isEmpty {
                    Text(snapshot.nextAlarmLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.chalkFaded)
                        .lineLimit(1)
                }
            } else {
                Text("No alarms set")
                    .font(.headline)
                    .foregroundStyle(Theme.chalk)
            }

            Spacer(minLength: 0)

            Label("\(snapshot.currentStreak) day streak", systemImage: "flame.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.chalkYellow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let alarmPart: String
        if let next = snapshot.nextAlarmDate, next > Date() {
            let time = next.formatted(date: .omitted, time: .shortened)
            alarmPart = snapshot.nextAlarmLabel.isEmpty
                ? "Next alarm at \(time)."
                : "Next alarm \(snapshot.nextAlarmLabel) at \(time)."
        } else {
            alarmPart = "No alarms set."
        }
        return "\(alarmPart) Current streak \(snapshot.currentStreak) days."
    }
}

private struct LockedWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Next Alarm", systemImage: "alarm.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.chalkFaded)

            // A real preview of the paid feature, dimmed, so the locked state is
            // honest about what Premium adds rather than a bare advertisement.
            Text("7:00 AM")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.chalk.opacity(0.35))
                .redacted(reason: .placeholder)

            Spacer(minLength: 0)

            Label("Premium feature", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.chalkYellow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetSharedStore.paywallURL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next alarm widget, locked. Tap to unlock Premium.")
    }
}

// MARK: - Colors

/// Local palette so the widget stays self-contained (the app's Theme depends on
/// app-only state). Kept visually aligned with the app's chalkboard look.
private enum Theme {
    static let board       = Color(red: 0.11, green: 0.20, blue: 0.17)
    static let chalk       = Color(red: 0.96, green: 0.96, blue: 0.93)
    static let chalkFaded  = Color(red: 0.96, green: 0.96, blue: 0.93).opacity(0.65)
    static let chalkYellow = Color(red: 0.98, green: 0.84, blue: 0.36)
}
