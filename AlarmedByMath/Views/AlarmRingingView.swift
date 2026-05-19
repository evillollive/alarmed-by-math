import SwiftUI

/// Full-screen view shown while an alarm is actively ringing.
/// The user must tap "Solve to Dismiss" to proceed to the math challenge.
struct AlarmRingingView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler

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
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Pulsing alarm icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulsing ? 1.25 : 1.0)
                        .animation(
                            .easeInOut(duration: 1).repeatForever(autoreverses: true),
                            value: pulsing
                        )

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                }

                // Time + optional label
                VStack(spacing: 8) {
                    if let label = currentAlarm?.label, !label.isEmpty {
                        Text(label)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(currentTimeString)
                        .font(.system(size: 80, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // CTA
                Button {
                    showingMath = true
                } label: {
                    Text("Solve to Dismiss")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
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
        }
    }

    private var currentTimeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: Date())
    }
}
