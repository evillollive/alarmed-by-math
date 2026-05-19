import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @State private var showingAddAlarm = false

    var body: some View {
        NavigationView {
            Group {
                if alarmStore.alarms.isEmpty {
                    emptyState
                } else {
                    alarmList
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddAlarm = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView()
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
            }
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(isPresented: $scheduler.isRinging) {
            AlarmRingingView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Alarms")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Tap + to add an alarm")
                .foregroundColor(.secondary)
        }
    }

    private var alarmList: some View {
        List {
            ForEach(alarmStore.alarms) { alarm in
                AlarmRow(alarm: alarm)
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
            }
            .onDelete { offsets in
                offsets.map { alarmStore.alarms[$0] }.forEach { scheduler.cancel($0) }
                alarmStore.delete(at: offsets)
            }
        }
    }
}

// MARK: - AlarmRow

struct AlarmRow: View {
    let alarm: Alarm
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                HStack(spacing: 6) {
                    if !alarm.label.isEmpty {
                        Text(alarm.label)
                            .foregroundColor(.secondary)
                    }
                    Text(alarm.repeatLabel)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in
                    // Capture old value before toggling
                    let wasEnabled = alarm.isEnabled
                    alarmStore.toggle(alarm)
                    if wasEnabled {
                        scheduler.cancel(alarm)
                    } else {
                        scheduler.schedule(alarm)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
