import SwiftUI

@main
struct AlarmedByMathApp: App {
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var scheduler  = AlarmScheduler()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
                .onAppear {
                    scheduler.requestPermission { _ in }
                    scheduler.scheduleAlarms(alarmStore.alarms)
                }
        }
    }
}
