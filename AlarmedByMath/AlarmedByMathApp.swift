import SwiftUI

@main
struct AlarmedByMathApp: App {
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var scheduler = AlarmScheduler()
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
                .environmentObject(settings)
                .colorScheme(settings.activeTheme.colorScheme)
                .onAppear {
                    Task {
                        await settings.prepareStoreKitIfNeeded()
                        await settings.refreshWhizEntitlements(showConfirmation: false)
                    }
                    alarmStore.applyEntitlements()
                    scheduler.requestPermission { _ in }
                    scheduler.scheduleAlarms(alarmStore.alarms)
                    if !scheduler.presentMathIfPending() {
                        scheduler.presentMathIfActiveRing()
                    }
                }
                .onReceive(settings.$whizPlan) { _ in
                    alarmStore.applyEntitlements()
                    scheduler.scheduleAlarms(alarmStore.alarms)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await settings.prepareStoreKitIfNeeded()
                await settings.refreshWhizEntitlements(showConfirmation: false)
            }
            alarmStore.applyEntitlements()
            scheduler.scheduleAlarms(alarmStore.alarms)
            if !scheduler.presentMathIfPending() {
                scheduler.presentMathIfActiveRing()
            }
        }
    }
}
