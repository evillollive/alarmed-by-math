import SwiftUI

@main
struct AlarmedByMathApp: App {
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var scheduler  = AlarmScheduler()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
                .onAppear {
                    scheduler.requestPermission { _ in }
                    scheduler.scheduleAlarms(alarmStore.alarms)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        scheduler.refreshPermissionStatus()
                        scheduler.scheduleAlarms(alarmStore.alarms)
                    default:
                        break
                    }
                }
        }
    }
}
