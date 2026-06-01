import SwiftUI

@main
struct AlarmedByMathApp: App {
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var scheduler  = AlarmScheduler()
    @StateObject private var settings   = SettingsStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
                .environmentObject(settings)
                .colorScheme(settings.activeTheme.colorScheme)
                .onAppear {
                    scheduler.requestPermission { _ in }
                    scheduler.scheduleAlarms(alarmStore.alarms)
                    if !scheduler.presentMathIfPending() {
                        scheduler.presentMathIfActiveRing()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Refresh schedules (keeps the chained-notification budget current)
            // and pick up any alarm whose "Solve to Dismiss" button was tapped,
            // or that is still ringing, so the math gate can't be skipped.
            scheduler.scheduleAlarms(alarmStore.alarms)
            if !scheduler.presentMathIfPending() {
                scheduler.presentMathIfActiveRing()
            }
        }
    }
}
