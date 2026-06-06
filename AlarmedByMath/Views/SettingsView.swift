import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var scheduler: AlarmScheduler
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Theme.board.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        themeSection
                        soundSection
                        premiumSection
                        testAlarmSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.boardDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(
                settings.activeTheme.colorScheme == .light ? .light : .dark,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.chalkYellow)
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            await settings.prepareStoreKitIfNeeded()
        }
        .colorScheme(settings.activeTheme.colorScheme)
    }

    private var themeSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Theme")
                Text("Each palette keeps the main reading colors above accessibility contrast targets, and the full row is tappable.")
                    .font(.caption)
                    .foregroundColor(Theme.chalkFaded)
                VStack(spacing: 8) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeRow(theme: theme, isSelected: settings.activeTheme == theme) {
                            settings.activeTheme = theme
                        }
                    }
                }
            }
        }
    }

    private var soundSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Default Alarm Sound")
                HStack(spacing: 8) {
                    ForEach(AlarmSound.allCases, id: \.self) { sound in
                        DayToggleButton(
                            title: sound.label,
                            isSelected: settings.alarmSound == sound
                        ) {
                            settings.alarmSound = sound
                            scheduler.previewSound(sound)
                        }
                    }
                }
                Text("Tap to preview. Turn your volume up to hear it, previews follow the media volume level even when your phone is on silent.")
                    .font(.caption2)
                    .foregroundColor(Theme.chalkFaded)
            }
        }
    }

    private var premiumSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Premium")
                Text(settings.isWhizUnlocked
                     ? "Premium is unlocked on this device, and the app will keep that purchase in sync with the App Store."
                     : "Free alarms go up to Expert. Premium is the paid unlock for tougher math and future paid extras.")
                    .font(.caption)
                    .foregroundColor(Theme.chalkFaded)
                    .accessibilityLabel(settings.isWhizUnlocked
                                        ? "Premium is unlocked on this device."
                                        : "Premium is locked. Free alarms go up to Expert.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("- Premium-level math difficulty")
                    Text("- Custom songs when the scheduler path supports them")
                    Text("- Home-screen widget roadmap")
                }
                .font(.caption)
                .foregroundColor(Theme.chalk)
                .accessibilityElement(children: .combine)

                if let price = settings.whizPrice, !settings.isWhizUnlocked {
                    Text("Unlock once for \(price).")
                        .font(.caption)
                        .foregroundColor(Theme.chalkYellow)
                }

                if settings.isLoadingWhizStore {
                    ProgressView("Loading Premium purchase details…")
                        .tint(Theme.chalkYellow)
                        .foregroundColor(Theme.chalkFaded)
                        .accessibilityLabel("Loading Premium purchase details")
                }

                VStack(spacing: 10) {
                    if !settings.isWhizUnlocked {
                        Button {
                            Task { await settings.purchaseWhiz() }
                        } label: {
                            actionButtonLabel(
                                title: settings.isPurchasingWhiz ? "Purchasing Premium…" : "Unlock Premium",
                                systemImage: "sparkles",
                                fill: Theme.chalkYellow,
                                foreground: Theme.boardDark
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!settings.canPurchaseWhiz)
                        .opacity(settings.canPurchaseWhiz ? 1 : 0.6)
                        .accessibilityIdentifier("settings.unlock-premium")
                        .accessibilityHint("Starts the App Store purchase for the premium unlock")
                    }

                    Button {
                        Task { await settings.restorePurchases() }
                    } label: {
                        actionButtonLabel(
                            title: settings.isRestoringPurchases ? "Restoring Purchases…" : "Restore Purchases",
                            systemImage: "arrow.clockwise",
                            fill: Theme.board,
                            foreground: Theme.chalk
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.isPurchasingWhiz || settings.isRestoringPurchases)
                    .opacity(settings.isPurchasingWhiz || settings.isRestoringPurchases ? 0.6 : 1)
                    .accessibilityIdentifier("settings.restore-premium")
                    .accessibilityHint("Checks the App Store for a previous premium purchase")
                }

                if let status = settings.storeStatusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(Theme.chalkFaded)
                        .accessibilityLabel(status)
                }

#if DEBUG
                Toggle("Debug unlock Premium", isOn: Binding(
                    get: { settings.isWhizUnlocked },
                    set: { settings.setWhizUnlockedForDebug($0) }
                ))
                .tint(Theme.chalkYellow)
#endif
            }
        }
    }

    private var testAlarmSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Test Alarm")
                Text("Triggers the ringing screen immediately so you can preview the sound and math challenge. It plays even on silent, but turn your volume up to hear it, the test follows your media volume level. Real scheduled alarms use the system alarm volume instead.")
                    .font(.caption)
                    .foregroundColor(Theme.chalkFaded)
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        scheduler.startRinging(alarmID: "test", preview: true)
                    }
                } label: {
                    actionButtonLabel(
                        title: "Trigger Test Alarm",
                        systemImage: "alarm.fill",
                        fill: Theme.chalkRed,
                        foreground: Theme.chalk
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Starts the in-app ringing screen right away")
            }
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding()
        .background(Theme.boardDark.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.chalk.opacity(0.25), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: Theme.fontDesign))
            .fontWeight(.semibold)
            .foregroundColor(Theme.chalkYellow)
    }

    private func actionButtonLabel(
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
        .padding(.vertical, 12)
        .background(fill)
        .foregroundColor(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ThemeRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    private var previewColors: ThemeColors { theme.colors }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(previewColors.board)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 4)
                        .fill(previewColors.chalkYellow)
                        .frame(width: 22, height: 22)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(previewColors.chalkBlue)
                        .frame(width: 22, height: 22)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.label)
                        .font(.system(.body, design: previewColors.fontDesign))
                        .foregroundColor(Theme.chalk)
                    Text(theme == .highContrast ? "Maximum separation" : theme == .retro ? "Sharper LCD contrast" : "Accessible palette")
                        .font(.caption2)
                        .foregroundColor(Theme.chalkFaded)
                }

                Spacer(minLength: 12)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.chalkYellow)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.chalkYellow.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Theme.chalkYellow : Theme.chalk.opacity(0.2),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSelected ? "\(theme.label), selected" : theme.label)
        .accessibilityHint("Double tap to switch the app theme")
    }
}
