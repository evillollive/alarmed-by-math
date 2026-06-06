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
        let calendar = Calendar.current
        let now = Date()

        // One entry per minute for the next two hours so the on-widget clock
        // stays accurate (WidgetKit can't tick per-second) and keeps moving even
        // if the system is slow to honor `.atEnd`. The snapshot is identical
        // across entries; only the displayed minute advances, and each entry
        // re-evaluates the next-alarm freshness against its own date. The app
        // also pushes reloads on data changes (alarms, entitlement, theme).
        let minuteComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let startOfMinute = calendar.date(from: minuteComponents) ?? now

        let entries: [AlarmEntry] = (0..<120).map { offset in
            let date = calendar.date(byAdding: .minute, value: offset, to: startOfMinute) ?? startOfMinute
            return AlarmEntry(date: date, snapshot: snapshot)
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct AlarmedByMathWidget: Widget {
    private let kind = "AlarmedByMathWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmProvider()) { entry in
            AlarmWidgetView(entry: entry)
                .containerBackground(entry.snapshot.theme.board.color, for: .widget)
        }
        .configurationDisplayName("Clock & Next Alarm")
        .description("A themed clock, plus your next alarm and solve streak. Alarm and streak details are a Premium feature.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct AlarmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlarmEntry

    private var snapshot: WidgetSharedStore.Snapshot { entry.snapshot }
    private var palette: WidgetSharedStore.ThemePalette { snapshot.theme }
    private var config: WidgetSharedStore.WidgetConfig { snapshot.config }

    var body: some View {
        Group {
            if family == .systemMedium {
                MediumLayout(entry: entry)
            } else {
                SmallLayout(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(snapshot.isPremiumUnlocked ? nil : WidgetSharedStore.paywallURL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let clock = entry.date.formatted(date: .omitted, time: .shortened)
        var parts = ["Current time \(clock)."]

        if let dateStr = config.dateString(for: entry.date) {
            parts.append("\(dateStr).")
        }

        if snapshot.isPremiumUnlocked {
            let visibleLimit = family == .systemMedium ? config.upcomingCount : 1
            let visible = snapshot.upcomingAlarms.filter { $0.date > entry.date }.prefix(visibleLimit)
            if let next = visible.first {
                let time = next.date.formatted(date: .omitted, time: .shortened)
                parts.append(next.label.isEmpty
                    ? "Next alarm at \(time)."
                    : "Next alarm \(next.label) at \(time).")
                if visible.count > 1 {
                    parts.append("\(visible.count - 1) more upcoming.")
                }
            } else {
                parts.append("No alarms set.")
            }
            if config.showStreak {
                parts.append("Current streak \(snapshot.currentStreak) days.")
            }
        } else {
            parts.append("Next alarm and streak are locked. Tap to unlock Premium.")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Layouts

private struct SmallLayout: View {
    let entry: AlarmEntry

    private var snapshot: WidgetSharedStore.Snapshot { entry.snapshot }
    private var palette: WidgetSharedStore.ThemePalette { snapshot.theme }
    private var config: WidgetSharedStore.WidgetConfig { snapshot.config }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ClockView(date: entry.date, config: config, palette: palette,
                      analogSize: config.compactAnalogSize)

            DateLabel(date: entry.date, config: config, palette: palette)

            if snapshot.isPremiumUnlocked {
                UpcomingAlarmsView(
                    alarms: snapshot.visibleAlarms(after: entry.date, limit: 1),
                    config: config, palette: palette
                )
                if config.showStreak {
                    StreakLabel(streak: snapshot.currentStreak, palette: palette)
                }
            } else {
                LockedDetailView(config: config, palette: palette)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MediumLayout: View {
    let entry: AlarmEntry

    private var snapshot: WidgetSharedStore.Snapshot { entry.snapshot }
    private var palette: WidgetSharedStore.ThemePalette { snapshot.theme }
    private var config: WidgetSharedStore.WidgetConfig { snapshot.config }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                ClockView(date: entry.date, config: config, palette: palette,
                          analogSize: config.mediumAnalogSize)
                DateLabel(date: entry.date, config: config, palette: palette)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 6) {
                if snapshot.isPremiumUnlocked {
                    UpcomingAlarmsView(
                        alarms: snapshot.visibleAlarms(after: entry.date, limit: config.upcomingCount),
                        config: config, palette: palette
                    )
                    if config.showStreak {
                        StreakLabel(streak: snapshot.currentStreak, palette: palette)
                    }
                } else {
                    LockedDetailView(config: config, palette: palette)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Components

private struct ClockView: View {
    let date: Date
    let config: WidgetSharedStore.WidgetConfig
    let palette: WidgetSharedStore.ThemePalette
    /// Fixed size for the analog face; nil lets it fill the container.
    var analogSize: CGFloat? = nil

    var body: some View {
        if config.isAnalog {
            AnalogClock(date: date, palette: palette)
                .modifier(AnalogSizing(size: analogSize))
        } else {
            Text(date, style: .time)
                .font(.system(size: config.clockPointSize, weight: .bold, design: palette.design))
                .foregroundStyle(palette.chalk.color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

private struct AnalogSizing: ViewModifier {
    let size: CGFloat?

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size, height: size)
        } else {
            content
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct AnalogClock: View {
    let date: Date
    let palette: WidgetSharedStore.ThemePalette

    private var minute: Double { Double(Calendar.current.component(.minute, from: date)) }
    private var hour: Double { Double(Calendar.current.component(.hour, from: date) % 12) }
    private var minuteAngle: Double { minute / 60 * 360 }
    private var hourAngle: Double { (hour + minute / 60) / 12 * 360 }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(palette.chalkFaded.color.opacity(0.7), lineWidth: max(1.5, s * 0.025))

                ForEach(0..<12, id: \.self) { tick in
                    Capsule()
                        .fill(palette.chalkFaded.color)
                        .frame(width: max(1.5, s * 0.02), height: s * 0.07)
                        .offset(y: -s * 0.43)
                        .rotationEffect(.degrees(Double(tick) / 12 * 360))
                }

                hand(length: s * 0.26, width: max(2, s * 0.045), angle: hourAngle, color: palette.chalk.color)
                hand(length: s * 0.38, width: max(1.5, s * 0.03), angle: minuteAngle, color: palette.chalk.color)

                Circle()
                    .fill(palette.chalkYellow.color)
                    .frame(width: s * 0.08, height: s * 0.08)
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func hand(length: CGFloat, width: CGFloat, angle: Double, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}

private struct DateLabel: View {
    let date: Date
    let config: WidgetSharedStore.WidgetConfig
    let palette: WidgetSharedStore.ThemePalette

    var body: some View {
        if let text = config.dateString(for: date) {
            Text(text)
                .font(.system(config.detailTextStyle, design: palette.design))
                .foregroundStyle(palette.chalkFaded.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct UpcomingAlarmsView: View {
    let alarms: [WidgetSharedStore.UpcomingAlarm]
    let config: WidgetSharedStore.WidgetConfig
    let palette: WidgetSharedStore.ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if alarms.isEmpty {
                Label("No alarms set", systemImage: "alarm")
                    .font(.system(config.detailTextStyle, design: palette.design).weight(.semibold))
                    .foregroundStyle(palette.chalkFaded.color)
            } else {
                ForEach(Array(alarms.enumerated()), id: \.offset) { index, alarm in
                    VStack(alignment: .leading, spacing: 1) {
                        Label {
                            Text(alarm.date, style: .time)
                        } icon: {
                            Image(systemName: index == 0 ? "alarm.fill" : "alarm")
                        }
                        .font(.system(config.detailTextStyle, design: palette.design).weight(.semibold))
                        .foregroundStyle(index == 0 ? palette.chalk.color : palette.chalkFaded.color)

                        if !alarm.label.isEmpty {
                            Text(alarm.label)
                                .font(.caption2)
                                .foregroundStyle(palette.chalkFaded.color)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

private struct StreakLabel: View {
    let streak: Int
    let palette: WidgetSharedStore.ThemePalette

    var body: some View {
        Label("\(streak) day streak", systemImage: "flame.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.chalkYellow.color)
    }
}

private struct LockedDetailView: View {
    let config: WidgetSharedStore.WidgetConfig
    let palette: WidgetSharedStore.ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // A real preview of the paid feature, dimmed, so the locked state is
            // honest about what Premium adds rather than a bare advertisement.
            Label {
                Text("7:00 AM")
            } icon: {
                Image(systemName: "alarm.fill")
            }
            .font(.system(config.detailTextStyle, design: palette.design).weight(.semibold))
            .foregroundStyle(palette.chalk.color.opacity(0.35))
            .redacted(reason: .placeholder)

            Label("Premium feature", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.chalkYellow.color)
        }
    }
}

// MARK: - Snapshot / config helpers

private extension WidgetSharedStore.Snapshot {
    /// Upcoming alarms that are still in the future relative to `date`, capped at
    /// `limit`. Re-filtering per entry keeps fired alarms from lingering as the
    /// minute-by-minute timeline advances.
    func visibleAlarms(after date: Date, limit: Int) -> [WidgetSharedStore.UpcomingAlarm] {
        Array(upcomingAlarms.filter { $0.date > date }.prefix(max(0, limit)))
    }
}

private extension WidgetSharedStore.WidgetConfig {
    var isAnalog: Bool { clockStyle == "analog" }

    var clockPointSize: CGFloat {
        switch textSize {
        case "small": return 30
        case "large": return 46
        default:      return 38
        }
    }

    var compactAnalogSize: CGFloat {
        switch textSize {
        case "small": return 64
        case "large": return 92
        default:      return 78
        }
    }

    var mediumAnalogSize: CGFloat {
        switch textSize {
        case "small": return 88
        case "large": return 120
        default:      return 104
        }
    }

    var detailTextStyle: Font.TextStyle {
        switch textSize {
        case "small": return .caption
        case "large": return .body
        default:      return .subheadline
        }
    }

    func dateString(for date: Date) -> String? {
        switch dateStyle {
        case "weekday": return date.formatted(.dateTime.weekday(.wide))
        case "short":   return date.formatted(.dateTime.month(.abbreviated).day())
        case "full":    return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        default:        return nil
        }
    }
}

// MARK: - Theme bridging

private extension WidgetSharedStore.ThemeRGB {
    var color: Color { Color(red: r, green: g, blue: b) }
}

private extension WidgetSharedStore.ThemePalette {
    var design: Font.Design {
        switch fontDesign {
        case "serif":      return .serif
        case "rounded":    return .rounded
        case "monospaced": return .monospaced
        default:           return .default
        }
    }
}
