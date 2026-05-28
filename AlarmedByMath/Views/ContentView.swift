import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @State private var showingAddAlarm = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        NavigationStack {
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
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView()
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
            }
            .sheet(item: $editingAlarm) { alarm in
                AddAlarmView(editingAlarm: alarm)
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
            }
            .overlay(alignment: .top) {
                if !scheduler.notificationsAuthorized {
                    notificationWarning
                }
            }
        }
        .fullScreenCover(isPresented: $scheduler.isRinging) {
            AlarmRingingView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
        }
    }

    // MARK: - Subviews

    private var notificationWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("Notifications disabled — alarms won't ring.")
                .font(.caption)
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

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
                AlarmRow(alarm: alarm, onEdit: { editingAlarm = alarm })
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
    var onEdit: () -> Void = {}
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler

    var body: some View {
        Button(action: onEdit) {
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
                        if alarm.isOneTime && alarm.hasFired {
                            Text("(Fired)")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in
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
                .accessibilityLabel("Alarm \(alarm.timeString)")
                .accessibilityValue(alarm.isEnabled ? "On" : "Off")
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to edit")
    }
}
