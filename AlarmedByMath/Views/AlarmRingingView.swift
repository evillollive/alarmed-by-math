import SwiftUI

/// Full-screen view shown while an alarm is actively ringing.
/// The user must tap "Solve to Dismiss" to proceed to the math challenge.
struct AlarmRingingView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @EnvironmentObject var settings:   SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingMath = false
    @State private var pulsing     = false

    private var currentAlarm: Alarm? {
        guard
            let idString = scheduler.activeAlarmID,
            let uuid     = UUID(uuidString: idString)
        else { return nil }
        return alarmStore.alarms.first { $0.id == uuid }
    }

    var body: some View {
        ZStack {
            ChalkboardBackground()

            ScrollView {
                VStack(spacing: 28) {
                    Text("Morning, on purpose.")
                        .font(AppTypography.title)
                        .foregroundStyle(Theme.chalk)
                    // Pulsing alarm icon
                    ZStack {
                        Circle()
                            .fill(Theme.chalkRed.opacity(0.12))
                            .frame(width: 200, height: 200)
                            .scaleEffect(reduceMotion ? 1.0 : (pulsing ? 1.3 : 1.0))
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: pulsing
                            )
                        Circle()
                            .stroke(Theme.chalkRed.opacity(0.35), lineWidth: 2)
                            .frame(width: 200, height: 200)
                            .scaleEffect(reduceMotion ? 1.0 : (pulsing ? 1.3 : 1.0))
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: pulsing
                            )
                        ChalkClockMark()
                            .frame(width: 160, height: 160)
                    }
                    .frame(height: 240)
                    .accessibilityHidden(true)

                    // Time + optional label
                    VStack(spacing: 8) {
                        if let label = currentAlarm?.label, !label.isEmpty {
                            Text(label)
                                .font(AppTypography.title)
                                .foregroundColor(Theme.chalkFaded)
                        }
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            Text(context.date, style: .time)
                                .font(AppTypography.display)
                                .monospacedDigit()
                                .foregroundColor(Theme.chalkYellow)
                        }
                    }

                    // CTA button
                    Button {
                        showingMath = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("∑")
                                .font(AppTypography.title)
                            Text("Solve to Dismiss")
                                .font(AppTypography.emphasis)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.chalkYellow)
                        .foregroundColor(Theme.boardDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.chalk.opacity(0.4), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Solve to dismiss alarm")
                    .accessibilityHint("Opens the math challenge")
                }
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .interactiveDismissDisabled(scheduler.isRinging)
        .onAppear {
            pulsing = !reduceMotion
            if scheduler.autoPresentMath { showingMath = true }
        }
        .onChange(of: scheduler.activeAlarmID) {
            showingMath = scheduler.autoPresentMath
        }
        .fullScreenCover(isPresented: $showingMath) {
            MathChallengeView()
                .id(scheduler.activeAlarmID)
                .environmentObject(scheduler)
                .environmentObject(alarmStore)
                .environmentObject(settings)
        }
    }
}
