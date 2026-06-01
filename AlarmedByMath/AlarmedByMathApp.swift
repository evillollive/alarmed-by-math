import SwiftUI

@main
struct AlarmedByMathApp: App {
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var scheduler  = AlarmScheduler()
    @StateObject private var settings   = SettingsStore.shared

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
                }
        }
    }
}
