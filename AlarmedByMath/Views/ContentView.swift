import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @EnvironmentObject var settings:   SettingsStore
    @State private var showingAddAlarm    = false
    @State private var alarmToEdit:       Alarm? = nil
    @State private var showingSettings    = false
    @State private var showingStats       = false
    @State private var now                = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.board.ignoresSafeArea()

                VStack(spacing: 0) {
                    if scheduler.notificationPermissionStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Notifications are off. Enable them in Settings so alarms can ring.")
                                .font(.system(.caption, design: Theme.fontDesign))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundColor(Theme.chalkRed)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.boardDark.opacity(0.7))
                    }

                    // Next alarm banner
                    if let label = alarmStore.nextAlarmLabel {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text("Next alarm \(label)")
                                .font(.system(.caption, design: Theme.fontDesign))
                        }
                        .foregroundColor(Theme.chalkYellow)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Theme.boardDark.opacity(0.6))
                    }

                    if alarmStore.alarms.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        alarmList
                    }
                }
            }
            .navigationTitle("Alarms")
            .onReceive(timer) { now = $0 }
            .onAppear { scheduler.refreshPermissionStatus() }
            .toolbarBackground(Theme.boardDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(settings.activeTheme.colorScheme == .light ? .light : .dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(Theme.chalkFaded)
                        }
                        Button { showingStats = true } label: {
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundColor(Theme.chalkFaded)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddAlarm = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(Theme.chalkYellow)
                    }
                }
            }
            // Add new alarm
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView()
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
                    .environmentObject(settings)
            }
            // Edit existing alarm
            .sheet(item: $alarmToEdit) { alarm in
                AddAlarmView(alarmToEdit: alarm)
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
                    .environmentObject(settings)
            }
            // Settings
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(settings)
                    .environmentObject(scheduler)
            }
            // Stats
            .sheet(isPresented: $showingStats) {
                StatsView()
                    .environmentObject(settings)
                    .environmentObject(alarmStore)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { scheduler.isRinging },
                set: { if !$0 { scheduler.dismiss() } }
            )
        ) {
            AlarmRingingView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
                .environmentObject(settings)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("∑ π ÷")
                .font(.system(size: 48, weight: .light, design: Theme.fontDesign))
                .foregroundColor(Theme.chalkFaded)
            Text("No Alarms")
                .font(.system(.title2, design: Theme.fontDesign))
                .foregroundColor(Theme.chalk)
            Text("Tap + to write your first alarm")
                .font(.subheadline)
                .foregroundColor(Theme.chalkFaded)
        }
    }

    private var alarmList: some View {
        List {
            ForEach(alarmStore.alarms) { alarm in
                AlarmRow(alarm: alarm, onEdit: { alarmToEdit = alarm })
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
                    .listRowBackground(Theme.boardDark.opacity(0.6))
                    .listRowSeparatorTint(Theme.chalk.opacity(0.2))
            }
            .onDelete { offsets in
                offsets.map { alarmStore.alarms[$0] }.forEach { scheduler.cancel($0) }
                alarmStore.delete(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - AlarmRow

struct AlarmRow: View {
    let alarm:  Alarm
    let onEdit: () -> Void
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler

    var body: some View {
        HStack {
            // Tappable content area opens edit sheet
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeString)
                        .font(.system(size: 38, weight: .light, design: Theme.fontDesign))
                        .foregroundColor(alarm.isEnabled ? Theme.chalk : Theme.chalkFaded)
                    Text(alarm.detailLabel)
                        .font(.subheadline)
                        .foregroundColor(Theme.chalkFaded)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in
                    let wasEnabled = alarm.isEnabled
                    alarmStore.toggle(alarm)
                    guard let refreshed = alarmStore.alarms.first(where: { $0.id == alarm.id }) else { return }
                    if wasEnabled { scheduler.cancel(refreshed) } else { scheduler.schedule(refreshed) }
                }
            ))
            .tint(Theme.chalkYellow)
            .labelsHidden()
        }
        .padding(.vertical, 6)
    }
}
