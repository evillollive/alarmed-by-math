import SwiftUI

/// Canonical Premium upsell. Locked features across the app present this sheet
/// instead of duplicating purchase copy, so there's a single place that pitches
/// Premium, shows the price, and runs the StoreKit purchase/restore flow.
struct PaywallView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    /// Short context line describing which locked feature brought the user here.
    var context: String?

    private let features: [(symbol: String, text: String)] = [
        ("function", "Whiz scientific problems: roots, logs, trig, and more"),
        ("music.note", "Play a song from your library while you solve the alarm"),
        ("square.grid.2x2", "A Home Screen widget with your next alarm and solve streak")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.text) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: feature.symbol)
                                    .foregroundColor(Theme.chalkYellow)
                                    .frame(width: 24)
                                Text(feature.text)
                                    .font(.system(.body, design: Theme.fontDesign))
                                    .foregroundColor(Theme.chalk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Premium includes: " + features.map(\.text).joined(separator: ", "))

                    purchaseSection
                    messages
                    legalLinks
                }
                .padding(24)
            }
            .background(Theme.board.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.chalkFaded)
                }
            }
        }
        .colorScheme(settings.activeTheme.colorScheme)
        .task { await settings.prepareStoreKitIfNeeded() }
        .onChange(of: settings.isWhizUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(Theme.chalkYellow)
            Text("Unlock Premium")
                .font(.system(.title, design: Theme.fontDesign))
                .fontWeight(.bold)
                .foregroundColor(Theme.chalk)
            if let context {
                Text(context)
                    .font(.system(.subheadline, design: Theme.fontDesign))
                    .foregroundColor(Theme.chalkFaded)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("A one-time purchase. Free alarms still go all the way up to Expert; your phone always wakes you with the dependable alarm sound from Settings.")
                .font(.caption)
                .foregroundColor(Theme.chalkFaded)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if settings.isLoadingWhizStore {
            ProgressView("Loading purchase details…")
                .tint(Theme.chalkYellow)
                .foregroundColor(Theme.chalkFaded)
                .frame(maxWidth: .infinity)
        }

        if let price = settings.whizPrice, !settings.isWhizUnlocked {
            Text("Unlock once for \(price).")
                .font(.system(.headline, design: Theme.fontDesign))
                .foregroundColor(Theme.chalkYellow)
        }

        VStack(spacing: 10) {
            if !settings.isWhizUnlocked {
                Button {
                    Task { await settings.purchaseWhiz() }
                } label: {
                    buttonLabel(
                        title: settings.isPurchasingWhiz ? "Purchasing…" : "Unlock Premium",
                        systemImage: "sparkles",
                        fill: Theme.chalkYellow,
                        foreground: Theme.boardDark
                    )
                }
                .buttonStyle(.plain)
                .disabled(!settings.canPurchaseWhiz)
                .opacity(settings.canPurchaseWhiz ? 1 : 0.6)
                .accessibilityIdentifier("paywall.unlock-premium")
                .accessibilityHint("Starts the App Store purchase for the premium unlock")
            }

            Button {
                Task { await settings.restorePurchases() }
            } label: {
                buttonLabel(
                    title: settings.isRestoringPurchases ? "Restoring…" : "Restore Purchases",
                    systemImage: "arrow.clockwise",
                    fill: Theme.boardDark,
                    foreground: Theme.chalk
                )
            }
            .buttonStyle(.plain)
            .disabled(settings.isPurchasingWhiz || settings.isRestoringPurchases)
            .opacity(settings.isPurchasingWhiz || settings.isRestoringPurchases ? 0.6 : 1)
            .accessibilityIdentifier("paywall.restore-premium")
            .accessibilityHint("Checks the App Store for a previous premium purchase")
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let status = settings.storeStatusMessage {
            Text(status)
                .font(.caption)
                .foregroundColor(Theme.chalkFaded)
                .accessibilityLabel(status)
        }
        if let error = settings.storeErrorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(Theme.chalkRed)
                .accessibilityLabel(error)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: PremiumLinks.termsOfUse)
            Link("Privacy Policy", destination: PremiumLinks.privacyPolicy)
            Spacer()
        }
        .font(.caption)
        .tint(Theme.chalkYellow)
        .foregroundColor(Theme.chalkYellow)
    }

    private func buttonLabel(
        title: String,
        systemImage: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(fill)
        .foregroundColor(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Legal URLs surfaced in the purchase UI. Apple requires functional Terms of
/// Use (EULA) and Privacy Policy links wherever an in-app purchase is offered.
enum PremiumLinks {
    /// Apple's standard EULA, which applies unless a custom one is provided.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://evillollive.github.io/alarmed-by-math/privacy.html")!
}
