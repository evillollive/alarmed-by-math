import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @EnvironmentObject var settings:   SettingsStore
    @State private var showingAddAlarm    = false
    @State private var alarmToEdit:       Alarm? = nil
    @State private var alarmToDuplicate:  Alarm? = nil
    @State private var showingSettings    = false
    @State private var showingStats       = false
    @State private var showingPractice    = false
    @State private var now                = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                ChalkboardBackground()

                alarmList
            }
            .navigationTitle("Alarms")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingPractice) {
                MathPracticeView()
                    .environmentObject(settings)
            }
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
                                .font(AppTypography.title)
                                .foregroundColor(Theme.chalkFaded)
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("alarms.settings")
                        Button { showingStats = true } label: {
                            Image(systemName: "trophy.fill")
                                .font(AppTypography.title)
                                .foregroundColor(Theme.chalkFaded)
                        }
                        .accessibilityLabel("Statistics")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddAlarm = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.title)
                            .foregroundColor(Theme.chalkYellow)
                    }
                    .accessibilityLabel("Add alarm")
                    .accessibilityIdentifier("alarms.add")
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
            .sheet(item: $alarmToDuplicate) { alarm in
                AddAlarmView(duplicating: alarm)
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
            // Premium upsell (also opened by the locked widget's deep link)
            .sheet(isPresented: $settings.isShowingPaywall) {
                PaywallView(context: "Unlock the Home Screen widget and the rest of Premium.")
                    .environmentObject(settings)
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

    @ViewBuilder
    private var readinessNotice: some View {
        if scheduler.permissionWarning != nil || scheduler.schedulingFailureMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                Label("Check your alarm setup", systemImage: "exclamationmark.circle")
                    .font(AppTypography.emphasis)
                    .foregroundStyle(Theme.chalkYellow)
                if let warning = scheduler.permissionWarning {
                    Text(warning)
                        .font(AppTypography.body)
                        .foregroundStyle(Theme.chalk)
                    if scheduler.needsPermissionRequest {
                        Button("Allow access") {
                            scheduler.requestPermission { granted in
                                if granted { scheduler.scheduleAlarms(alarmStore.alarms) }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.chalkYellow)
                    } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: settingsURL)
                            .font(AppTypography.emphasis)
                            .padding(.vertical, 8)
                            .tint(Theme.chalkYellow)
                    }
                }
                if let failure = scheduler.schedulingFailureMessage {
                    Text(failure)
                        .font(AppTypography.body)
                        .foregroundStyle(Theme.chalk)
                    Button("Retry scheduling") {
                        scheduler.scheduleAlarms(alarmStore.alarms)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.chalkYellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.boardDark, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.chalkYellow, lineWidth: 1)
            }
            .accessibilityIdentifier("alarms.readiness")
        }
    }

    private var scheduleSummary: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(AppTypography.body)
                    .foregroundStyle(Theme.chalkFaded)
                if let next = alarmStore.nextAlarmDate {
                    Text("Next in your schedule")
                        .font(AppTypography.title)
                        .foregroundStyle(Theme.chalk)
                    Text(next, style: .time)
                        .font(AppTypography.display)
                        .monospacedDigit()
                        .foregroundStyle(Theme.chalkYellow)
                    if let countdown = alarmStore.nextAlarmLabel {
                        Text(countdown)
                            .font(AppTypography.body)
                            .foregroundStyle(Theme.chalkFaded)
                    }
                } else {
                    Text("A little time off.")
                        .font(AppTypography.title)
                        .foregroundStyle(Theme.chalk)
                    Text("Your alarms are switched off.")
                        .font(AppTypography.body)
                        .foregroundStyle(Theme.chalkFaded)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ChalkClockMark()
                .frame(width: 78, height: 78)
        }
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ChalkClockMark()
                .frame(width: 180, height: 180)
                .padding(.top, 28)
            Text("Make room\nfor morning.")
                .font(AppTypography.title)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.chalk)
            Text("An alarm. A little math.\nA more awake you.")
                .font(AppTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.chalkFaded)
            Button {
                showingAddAlarm = true
            } label: {
                Label("Set your first alarm", systemImage: "plus")
                    .font(AppTypography.emphasis)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .foregroundStyle(Theme.boardDark)
                    .background(Theme.chalkYellow, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("alarms.create-first")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var alarmList: some View {
        List {
            readinessNotice
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if alarmStore.alarms.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                scheduleSummary
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(alarmStore.alarms) { alarm in
                AlarmRow(alarm: alarm, onEdit: { alarmToEdit = alarm },
                         onDuplicate: { alarmToDuplicate = alarm })
                    .environmentObject(alarmStore)
                    .environmentObject(scheduler)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Duplicate", systemImage: "doc.on.doc") { alarmToDuplicate = alarm }
                            .tint(Theme.chalkBlue)
                    }
            }
            .onDelete { offsets in
                offsets.map { alarmStore.alarms[$0] }.forEach { scheduler.cancel($0) }
                alarmStore.delete(at: offsets)
            }
            Button {
                showingPractice = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "function")
                        .font(AppTypography.title)
                        .foregroundStyle(Theme.chalkYellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Practice math")
                            .font(AppTypography.emphasis)
                            .foregroundStyle(Theme.chalk)
                        Text("Try a challenge without the alarm.")
                            .font(AppTypography.body)
                            .foregroundStyle(Theme.chalkFaded)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.chalkFaded)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("alarms.practice")
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - AlarmRow

struct AlarmRow: View {
    let alarm:  Alarm
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler

    var body: some View {
        HStack {
            // Tappable content area opens edit sheet
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeString)
                        .font(AppTypography.display)
                        .monospacedDigit()
                        .foregroundColor(alarm.isEnabled ? Theme.chalk : Theme.chalkFaded)
                    Text(alarm.detailLabel)
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalkFaded)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(alarm.displayLabel), \(alarm.timeString), \(alarm.repeatLabel)")
            .accessibilityHint("Opens alarm details")
            .accessibilityAction(named: Text("Duplicate alarm"), onDuplicate)
            .contextMenu {
                Button("Duplicate alarm", systemImage: "doc.on.doc", action: onDuplicate)
            }

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
            .accessibilityLabel("\(alarm.displayLabel), \(alarm.timeString)")
            .accessibilityValue(alarm.isEnabled ? "On" : "Off")
        }
        .padding(18)
        .background(Theme.boardDark, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.chalkFaded.opacity(0.35), lineWidth: 1)
        }
    }
}
