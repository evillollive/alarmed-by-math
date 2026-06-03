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
                    expirePastOneTimeAlarms()
                    scheduler.refreshPermissionStatus()
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
            expirePastOneTimeAlarms()
            scheduler.refreshPermissionStatus()
            scheduler.scheduleAlarms(alarmStore.alarms)
            if !scheduler.presentMathIfPending() {
                scheduler.presentMathIfActiveRing()
            }
        }
    }

    private func expirePastOneTimeAlarms() {
        var excluded: Set<UUID> = []
        if let activeID = scheduler.activeAlarmID, let uuid = UUID(uuidString: activeID) {
            excluded.insert(uuid)
        }
        if let pendingID = AlarmGate.pendingMathAlarmID, let uuid = UUID(uuidString: pendingID) {
            excluded.insert(uuid)
        }
        if #available(iOS 26.1, *) {
            for id in AlarmKitScheduler.alertingOriginalIDs() {
                if let uuid = UUID(uuidString: id) {
                    excluded.insert(uuid)
                }
            }
        }
        alarmStore.expireOneTimeAlarms(excludingIDs: excluded)
    }
}
