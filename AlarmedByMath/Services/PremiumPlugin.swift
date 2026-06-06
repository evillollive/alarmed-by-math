import SwiftUI

/// Capability surface for the paid "Premium" (Whiz) tier.
///
/// The free, open-source app ships without an implementation. The private
/// premium add-on (compiled in only for App Store distribution builds) provides
/// a concrete `WhizFeature` and registers it at launch. When no implementation
/// is present, the app falls back to free behavior everywhere, so the public
/// repository builds and runs as a complete free app on its own.
protocol WhizFeature {
    /// A random scientific-style problem for the Premium tier.
    func generateProblem() -> MathProblem

    /// The input pad shown for the Premium challenge.
    func keypad(input: Binding<String>, onSubmit: @escaping () -> Void) -> AnyView
}

/// Runtime registry the app consults to decide whether premium content exists.
enum PremiumPlugin {
    private(set) static var whiz: WhizFeature?

    /// `true` when the premium add-on has been compiled in and registered.
    static var isAvailable: Bool { whiz != nil }

    /// Called by the premium add-on's registrar to install its implementation.
    static func register(_ feature: WhizFeature) {
        whiz = feature
    }

    /// Discovers and installs the premium add-on if its sources are compiled
    /// into the app. Uses the Objective-C runtime so the free target links and
    /// runs without the add-on present. Idempotent and safe to call repeatedly.
    static func installIfAvailable() {
        guard whiz == nil, let registrar = NSClassFromString("ABMPremiumRegistrar") else { return }
        _ = (registrar as AnyObject).perform(Selector(("register")))
    }

    #if DEBUG
    /// Test hook: clears any registered implementation so each test starts from
    /// a known state regardless of execution order.
    static func resetForTesting() {
        whiz = nil
    }
    #endif
}
