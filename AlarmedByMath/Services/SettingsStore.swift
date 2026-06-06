import Foundation
import Combine
import StoreKit

enum WhizPlan: String, Codable {
    case free
    case whiz
}

// MARK: - Widget layout preferences

/// How the premium widget renders its clock. Mirrored into the App Group
/// snapshot (as raw strings) so the widget extension can honor the choice.
enum WidgetClockStyle: String, CaseIterable, Codable {
    case digital
    case analog

    var label: String {
        switch self {
        case .digital: return "Digital"
        case .analog:  return "Analog"
        }
    }
}

/// Relative size of the widget's clock and detail text.
enum WidgetTextSize: String, CaseIterable, Codable {
    case small
    case medium
    case large

    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }
}

/// Whether and how the widget shows the date alongside the clock.
enum WidgetDateStyle: String, CaseIterable, Codable {
    case off
    case weekday
    case short
    case full

    var label: String {
        switch self {
        case .off:     return "Off"
        case .weekday: return "Weekday"
        case .short:   return "Short"
        case .full:    return "Full"
        }
    }
}

private extension ProcessInfo {
    var isRunningUnitTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}

/// Stores user preferences and acts as the single source of truth for
/// active theme, alarm sound, snooze duration, and the premium entitlement.
///
/// `SettingsStore.shared` is used by `Theme` for color lookups so every
/// view automatically reflects the active theme when it re-renders.
final class SettingsStore: ObservableObject {

    static let whizProductID = "com.alarmedbymath.app.whiz"

    /// Singleton used by Theme for color lookups.
    static let shared = SettingsStore()

    @Published var activeTheme: AppTheme {
        didSet { UserDefaults.standard.set(activeTheme.rawValue, forKey: Keys.theme) }
    }

    @Published var alarmSound: AlarmSound {
        didSet { UserDefaults.standard.set(alarmSound.rawValue, forKey: Keys.sound) }
    }

    /// Snooze duration in minutes (how long before the alarm re-rings after the
    /// math challenge view is opened).
    @Published var snoozeDuration: Int {
        didSet { UserDefaults.standard.set(snoozeDuration, forKey: Keys.snooze) }
    }

    @Published private(set) var whizPlan: WhizPlan {
        didSet { UserDefaults.standard.set(whizPlan.rawValue, forKey: Keys.whizPlan) }
    }

    // MARK: - Widget layout preferences (Premium)

    /// Bounds for the "upcoming alarms" list the widget can show.
    static let widgetUpcomingCountRange = 1...3

    /// Fires whenever a widget layout preference changes so the app can re-push
    /// the App Group snapshot and reload the widget timelines.
    let widgetConfigChanged = PassthroughSubject<Void, Never>()

    @Published var widgetClockStyle: WidgetClockStyle {
        didSet {
            UserDefaults.standard.set(widgetClockStyle.rawValue, forKey: Keys.widgetClockStyle)
            widgetConfigChanged.send()
        }
    }

    @Published var widgetTextSize: WidgetTextSize {
        didSet {
            UserDefaults.standard.set(widgetTextSize.rawValue, forKey: Keys.widgetTextSize)
            widgetConfigChanged.send()
        }
    }

    @Published var widgetDateStyle: WidgetDateStyle {
        didSet {
            UserDefaults.standard.set(widgetDateStyle.rawValue, forKey: Keys.widgetDateStyle)
            widgetConfigChanged.send()
        }
    }

    /// Clamped to `widgetUpcomingCountRange` so a bad stored value can't escape.
    @Published var widgetUpcomingCount: Int {
        didSet {
            let clamped = min(max(widgetUpcomingCount, Self.widgetUpcomingCountRange.lowerBound),
                              Self.widgetUpcomingCountRange.upperBound)
            // Re-assigning inside didSet does not re-trigger the observer, so we
            // persist and publish the clamped value here rather than relying on
            // a second pass.
            if clamped != widgetUpcomingCount {
                widgetUpcomingCount = clamped
            }
            UserDefaults.standard.set(clamped, forKey: Keys.widgetUpcomingCount)
            widgetConfigChanged.send()
        }
    }

    @Published var widgetShowStreak: Bool {
        didSet {
            UserDefaults.standard.set(widgetShowStreak, forKey: Keys.widgetShowStreak)
            widgetConfigChanged.send()
        }
    }

    @Published private(set) var whizPrice: String?
    @Published private(set) var isLoadingWhizStore = false
    @Published private(set) var isPurchasingWhiz = false
    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var storeStatusMessage: String?
    @Published private(set) var storeErrorMessage: String?

    /// Drives the paywall sheet from anywhere (e.g. the locked widget's deep
    /// link). Settable so a deep link can request the upsell.
    @Published var isShowingPaywall = false

    var isWhizUnlocked: Bool { whizPlan == .whiz }
    var allowsWhizDifficulty: Bool { isWhizUnlocked && PremiumPlugin.isAvailable }
    var allowsCustomSongs: Bool { isWhizUnlocked }
    var allowsWidgetFeatures: Bool { isWhizUnlocked }
    var hasWhizProductLoaded: Bool { whizProduct != nil }
    var canPurchaseWhiz: Bool {
        hasWhizProductLoaded && !isWhizUnlocked && !isPurchasingWhiz && !isRestoringPurchases
    }

    private var whizProduct: Product?
    private var transactionUpdatesTask: Task<Void, Never>?
    private var hasPreparedStoreKit = false
    private let storeKitEnabled: Bool

    // MARK: - UserDefaults keys

    private enum Keys {
        static let theme = "settings_theme"
        static let sound = "settings_sound"
        static let snooze = "settings_snooze"
        static let whizPlan = "settings_whiz_plan"
        static let widgetClockStyle = "settings_widget_clock_style"
        static let widgetTextSize = "settings_widget_text_size"
        static let widgetDateStyle = "settings_widget_date_style"
        static let widgetUpcomingCount = "settings_widget_upcoming_count"
        static let widgetShowStreak = "settings_widget_show_streak"
    }

    // MARK: - Init

    init(storeKitEnabled: Bool = !ProcessInfo.processInfo.isRunningUnitTests) {
        self.storeKitEnabled = storeKitEnabled

        let themeRaw = UserDefaults.standard.string(forKey: Keys.theme) ?? ""
        activeTheme = AppTheme(rawValue: themeRaw) ?? .chalk

        let soundRaw = UserDefaults.standard.string(forKey: Keys.sound) ?? ""
        alarmSound = AlarmSound(rawValue: soundRaw) ?? .chime

        let stored = UserDefaults.standard.integer(forKey: Keys.snooze)
        snoozeDuration = stored > 0 ? stored : 5

        let planRaw = UserDefaults.standard.string(forKey: Keys.whizPlan) ?? ""
        whizPlan = WhizPlan(rawValue: planRaw) ?? .free

        let clockRaw = UserDefaults.standard.string(forKey: Keys.widgetClockStyle) ?? ""
        widgetClockStyle = WidgetClockStyle(rawValue: clockRaw) ?? .digital

        let sizeRaw = UserDefaults.standard.string(forKey: Keys.widgetTextSize) ?? ""
        widgetTextSize = WidgetTextSize(rawValue: sizeRaw) ?? .medium

        let dateRaw = UserDefaults.standard.string(forKey: Keys.widgetDateStyle) ?? ""
        widgetDateStyle = WidgetDateStyle(rawValue: dateRaw) ?? .weekday

        let countStored = UserDefaults.standard.integer(forKey: Keys.widgetUpcomingCount)
        widgetUpcomingCount = Self.widgetUpcomingCountRange.contains(countStored)
            ? countStored
            : Self.widgetUpcomingCountRange.lowerBound

        widgetShowStreak = UserDefaults.standard.object(forKey: Keys.widgetShowStreak) as? Bool ?? true
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

#if DEBUG
    func setWhizUnlockedForDebug(_ unlocked: Bool) {
        clearStoreMessages()
        whizPlan = unlocked ? .whiz : .free
    }
#endif

    func setWhizPlanFromEntitlement(_ plan: WhizPlan) {
        whizPlan = plan
    }

    @MainActor
    func prepareStoreKitIfNeeded() async {
        guard storeKitEnabled else { return }

        // First run wires up the transaction listener and entitlement refresh.
        if !hasPreparedStoreKit {
            hasPreparedStoreKit = true
            startTransactionListenerIfNeeded()
            await loadWhizProduct()
            await refreshWhizEntitlements(showConfirmation: false)
            return
        }

        // Later calls (e.g. reopening the paywall) retry a failed product load so
        // a transient App Store hiccup doesn't leave Unlock disabled until restart.
        if whizProduct == nil {
            await loadWhizProduct()
        }
    }

    @MainActor
    func refreshWhizEntitlements(showConfirmation: Bool = false) async {
        guard storeKitEnabled else { return }

        var unlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.whizProductID {
                unlocked = true
            }
        }

        setWhizPlanFromEntitlement(unlocked ? .whiz : .free)

        if showConfirmation {
            if unlocked {
                storeErrorMessage = nil
                storeStatusMessage = "Premium is unlocked on this device."
            } else {
                storeStatusMessage = "No premium purchase was found for this Apple Account yet."
            }
        }
    }

    @MainActor
    func purchaseWhiz() async {
        guard storeKitEnabled else { return }
        guard let product = whizProduct else {
            storeErrorMessage = "Premium isn't available to buy yet. Check that the App Store product is configured."
            return
        }

        clearStoreMessages()
        isPurchasingWhiz = true
        defer { isPurchasingWhiz = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    storeErrorMessage = "The App Store couldn't verify that purchase."
                    return
                }
                await transaction.finish()
                await refreshWhizEntitlements(showConfirmation: false)
                if isWhizUnlocked {
                    storeStatusMessage = "Premium unlocked. Your tougher math is ready."
                } else {
                    storeErrorMessage = "The purchase completed, but the unlock didn't refresh. Try Restore Purchases."
                }
            case .pending:
                storeStatusMessage = "Your purchase is pending approval."
            case .userCancelled:
                storeStatusMessage = "Purchase cancelled."
            @unknown default:
                storeErrorMessage = "The purchase didn't finish. Please try again."
            }
        } catch {
            storeErrorMessage = "Premium couldn't be purchased right now. Please try again."
        }
    }

    @MainActor
    func restorePurchases() async {
        guard storeKitEnabled else { return }

        clearStoreMessages()
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await AppStore.sync()
            await refreshWhizEntitlements(showConfirmation: true)
        } catch {
            storeErrorMessage = "Purchases couldn't be restored right now. Please try again."
        }
    }

    @MainActor
    private func loadWhizProduct() async {
        guard storeKitEnabled else { return }

        isLoadingWhizStore = true
        defer { isLoadingWhizStore = false }

        do {
            let products = try await Product.products(for: [Self.whizProductID])
            whizProduct = products.first
            whizPrice = whizProduct?.displayPrice

            if whizProduct == nil {
                storeStatusMessage = "Premium purchases are wired in the app, but the App Store product isn't live yet."
            }
        } catch {
            whizProduct = nil
            whizPrice = nil
            storeErrorMessage = "Premium details couldn't be loaded from the App Store."
        }
    }

    @MainActor
    private func startTransactionListenerIfNeeded() {
        guard storeKitEnabled, transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                if case .verified(let transaction) = result,
                   transaction.productID == Self.whizProductID {
                    await transaction.finish()
                }

                await self.refreshWhizEntitlements(showConfirmation: false)
            }
        }
    }

    private func clearStoreMessages() {
        storeStatusMessage = nil
        storeErrorMessage = nil
    }
}
