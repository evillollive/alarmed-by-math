import SwiftUI
import UIKit
import Combine

/// Controls which interface orientations the app allows at runtime.
/// The app is portrait-only everywhere except the Whiz scientific challenge,
/// which requests landscape. iPad keeps its full set of orientations.
enum AppOrientation {
    static var deviceDefault: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    }

    static var current: UIInterfaceOrientationMask = AppOrientation.deviceDefault

    /// Lock supported orientations and best-effort rotate the active window scene.
    /// Rotation is never required to solve a problem; if it fails the UI stays usable.
    static func lock(_ mask: UIInterfaceOrientationMask, rotateTo target: UIInterfaceOrientationMask) {
        current = mask
        apply(target)
    }

    static func reset() {
        current = deviceDefault
        apply(deviceDefault)
    }

    private static func apply(_ target: UIInterfaceOrientationMask) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        DispatchQueue.main.async {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { _ in }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppOrientation.current
    }
}

@main
struct AlarmedByMathApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var alarmStore: AlarmStore
    @StateObject private var scheduler: AlarmScheduler
    @StateObject private var settings: SettingsStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Install the premium add-on (if compiled in) before any store reads an
        // entitlement, so a paid user's saved Premium alarms are not downgraded
        // at load time.
        PremiumPlugin.installIfAvailable()
        _alarmStore = StateObject(wrappedValue: AlarmStore())
        _scheduler = StateObject(wrappedValue: AlarmScheduler())
        _settings = StateObject(wrappedValue: SettingsStore.shared)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStore)
                .environmentObject(scheduler)
                .environmentObject(settings)
                .font(AppTypography.body)
                .fontDesign(Theme.fontDesign)
                .colorScheme(settings.activeTheme.colorScheme)
                .onAppear {
                    Task {
                        await settings.prepareStoreKitIfNeeded()
                        await settings.refreshWhizEntitlements(showConfirmation: false)
                    }
                    scheduler.requestPermission { _ in }
                    refreshAlarms()
                }
                .onChange(of: settings.whizPlan) {
                    refreshAlarms()
                }
                .onChange(of: alarmStore.alarms) {
                    WidgetSync.refresh(alarmStore: alarmStore, settings: settings)
                }
                .onReceive(StatsStore.shared.$stats) { stats in
                    WidgetSync.refresh(alarmStore: alarmStore, settings: settings, currentStreak: stats.currentStreak)
                }
                .onChange(of: settings.activeTheme) {
                    WidgetSync.refresh(alarmStore: alarmStore, settings: settings)
                }
                .onChange(of: settings.alarmSound) {
                    scheduler.scheduleAlarms(alarmStore.alarms)
                }
                .onChange(of: scheduler.isRinging) { _, ringing in
                    if !ringing { refreshAlarms() }
                }
                .onChange(of: scheduler.activeAlarmID) { _, id in
                    if !scheduler.isPreview, let id = id.flatMap(UUID.init(uuidString:)) {
                        alarmStore.markOneTimeAlarmFired(id: id)
                    }
                }
                .onReceive(settings.widgetConfigChanged) { _ in
                    WidgetSync.refresh(alarmStore: alarmStore, settings: settings)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
                        .merge(
                            with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange),
                            NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                        )
                        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
                ) { _ in
                    if scenePhase == .active { refreshAlarms() }
                }
                .onOpenURL { url in
                    if url == WidgetSharedStore.paywallURL {
                        settings.isShowingPaywall = true
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await settings.prepareStoreKitIfNeeded()
                await settings.refreshWhizEntitlements(showConfirmation: false)
            }
            refreshAlarms()
        }
    }

    private func refreshAlarms() {
        var excluded = scheduler.ringingAlarmIDs
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
        alarmStore.applyEntitlements(excludingIDs: excluded)
        scheduler.refreshPermissionStatus()
        if !scheduler.presentMathIfPending() {
            scheduler.presentMathIfActiveRing()
        }
        // A clock refresh must not remove the current fallback snooze or queued alarms.
        if !scheduler.isRinging {
            scheduler.scheduleAlarms(alarmStore.alarms)
        }
        WidgetSync.refresh(alarmStore: alarmStore, settings: settings)
    }
}
