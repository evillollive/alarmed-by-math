import SwiftUI

/// Full-screen view shown while an alarm is actively ringing.
/// The user must tap "Solve to Dismiss" to proceed to the math challenge.
struct AlarmRingingView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @EnvironmentObject var settings:   SettingsStore

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
            Theme.boardDark.ignoresSafeArea()

            // Subtle ruled lines
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 44
                    var y: CGFloat = spacing
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(Theme.chalk.opacity(0.06), lineWidth: 1)
            }
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Pulsing alarm icon
                ZStack {
                    Circle()
                        .fill(Theme.chalkRed.opacity(0.12))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulsing ? 1.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 1).repeatForever(autoreverses: true),
                            value: pulsing
                        )
                    Circle()
                        .stroke(Theme.chalkRed.opacity(0.35), lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulsing ? 1.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 1).repeatForever(autoreverses: true),
                            value: pulsing
                        )
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Theme.chalkRed)
                }

                // Time + optional label
                VStack(spacing: 8) {
                    if let label = currentAlarm?.label, !label.isEmpty {
                        Text(label)
                            .font(.system(.title2, design: Theme.fontDesign))
                            .foregroundColor(Theme.chalkFaded)
                    }
                    Text(currentTimeString)
                        .font(.system(size: 80, weight: .thin, design: .monospaced))
                        .foregroundColor(Theme.chalk)
                }

                Spacer()

                // CTA button
                Button {
                    showingMath = true
                } label: {
                    HStack(spacing: 10) {
                        Text("∑")
                            .font(.title2)
                        Text("Solve to Dismiss")
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.chalkRed)
                    .foregroundColor(Theme.chalk)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.chalk.opacity(0.4), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear { pulsing = true }
        .fullScreenCover(isPresented: $showingMath) {
            MathChallengeView()
                .environmentObject(scheduler)
                .environmentObject(alarmStore)
                .environmentObject(settings)
        }
    }

    private var currentTimeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: Date())
    }
}
