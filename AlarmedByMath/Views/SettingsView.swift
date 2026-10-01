import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var scheduler: AlarmScheduler
    @Environment(\.dismiss) var dismiss
    @State private var showingSounds = false
    @ScaledMetric(relativeTo: .body) private var optionWidth = 96

    var body: some View {
        NavigationView {
            ZStack {
                Theme.board.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        themeSection
                        soundSection
                        premiumSection
                        if settings.isWhizUnlocked {
                            widgetSection
                        }
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
        .sheet(isPresented: $showingSounds) {
            SoundPickerView()
                .environmentObject(settings)
                .environmentObject(scheduler)
        }
    }

    private var themeSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Theme")
                Text("Each palette keeps the main reading colors above accessibility contrast targets, and the full row is tappable.")
                    .font(AppTypography.body)
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
                Text(settings.alarmSound.label)
                    .font(AppTypography.title)
                    .foregroundStyle(Theme.chalk)
                    .accessibilityIdentifier("sound.current")
                Text(settings.alarmSound.detail)
                    .font(AppTypography.body)
                    .foregroundStyle(Theme.chalkFaded)
                Button {
                    showingSounds = true
                } label: {
                    actionButtonLabel(
                        title: "Choose sound", systemImage: "waveform",
                        fill: Theme.chalkYellow, foreground: Theme.boardDark
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.choose-sound")
                Text("Applies to every alarm. You can preview a sound without changing your selection.")
                    .font(AppTypography.body)
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
                     : "Free alarms go up to Expert. Premium unlocks Whiz scientific problems, a custom song to play while you solve your alarm, and a Home Screen widget.")
                    .font(AppTypography.body)
                    .foregroundColor(Theme.chalkFaded)
                    .accessibilityLabel(settings.isWhizUnlocked
                                        ? "Premium is unlocked on this device."
                                        : "Premium is locked. Free alarms go up to Expert.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("- Whiz scientific math difficulty")
                    Text("- A custom song while you solve the alarm")
                    Text("- A Home Screen widget for your next alarm and streak")
                }
                .font(AppTypography.body)
                .foregroundColor(Theme.chalk)
                .accessibilityElement(children: .combine)

                if let price = settings.whizPrice, !settings.isWhizUnlocked {
                    Text("Unlock once for \(price).")
                        .font(AppTypography.body)
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
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalkFaded)
                        .accessibilityLabel(status)
                }

                if let error = settings.storeErrorMessage {
                    Text(error)
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalkRed)
                        .accessibilityLabel(error)
                }

                HStack(spacing: 16) {
                    Link("Terms of Use", destination: PremiumLinks.termsOfUse)
                    Link("Privacy Policy", destination: PremiumLinks.privacyPolicy)
                    Spacer()
                }
                .font(AppTypography.body)
                .tint(Theme.chalkYellow)
                .foregroundColor(Theme.chalkYellow)

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

    private var widgetSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Widget")
                Text("Customize the Home Screen widget. Changes apply the next time the widget refreshes.")
                    .font(AppTypography.body)
                    .foregroundColor(Theme.chalkFaded)

                widgetOptionRow("Clock") {
                    ForEach(WidgetClockStyle.allCases, id: \.self) { style in
                        DayToggleButton(
                            title: style.label,
                            isSelected: settings.widgetClockStyle == style
                        ) {
                            settings.widgetClockStyle = style
                        }
                    }
                }

                widgetOptionRow("Text size") {
                    ForEach(WidgetTextSize.allCases, id: \.self) { size in
                        DayToggleButton(
                            title: size.label,
                            isSelected: settings.widgetTextSize == size
                        ) {
                            settings.widgetTextSize = size
                        }
                    }
                }

                widgetOptionRow("Date") {
                    ForEach(WidgetDateStyle.allCases, id: \.self) { style in
                        DayToggleButton(
                            title: style.label,
                            isSelected: settings.widgetDateStyle == style
                        ) {
                            settings.widgetDateStyle = style
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Stepper(value: $settings.widgetUpcomingCount,
                            in: SettingsStore.widgetUpcomingCountRange) {
                        Text("Upcoming alarms: \(settings.widgetUpcomingCount)")
                            .font(AppTypography.body)
                            .foregroundColor(Theme.chalk)
                    }
                    .tint(Theme.chalkYellow)
                    Text("How many alarms the medium widget lists. The small widget always shows the next one.")
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalkFaded)
                }

                Toggle(isOn: $settings.widgetShowStreak) {
                    Text("Show solve streak")
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalk)
                }
                .tint(Theme.chalkYellow)
            }
        }
    }

    private func widgetOptionRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.emphasis)
                .foregroundColor(Theme.chalkFaded)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: min(optionWidth, 240)))], spacing: 8) {
                content()
            }
        }
    }

    private var testAlarmSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Test Alarm")
                Text("Triggers the ringing screen immediately so you can preview the sound and math challenge. It plays even on silent, but turn your volume up to hear it, the test follows your media volume level. Real scheduled alarms use the system alarm volume instead.")
                    .font(AppTypography.body)
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
            .font(AppTypography.body)
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

struct SoundPickerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var scheduler: AlarmScheduler
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                ChalkboardBackground()
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Find your morning voice.")
                                .font(AppTypography.title)
                                .foregroundStyle(Theme.chalk)
                            Text("Preview first. Select when ready. Previews play up to 24 seconds and can be stopped at any time. Start at a low volume; they use media volume and can play even on silent.")
                                .font(AppTypography.body)
                                .foregroundStyle(Theme.chalkFaded)
                            if let error = scheduler.previewErrorMessage {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(Theme.chalkRed)
                                    .font(AppTypography.body)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    ForEach(AlarmSound.Family.allCases, id: \.self) { family in
                        Section {
                            ForEach(AlarmSound.allCases.filter { $0.family == family }, id: \.self) { sound in
                                SoundChoiceRow(
                                    sound: sound,
                                    isSelected: settings.alarmSound == sound,
                                    isPreviewing: scheduler.previewingSound == sound,
                                    onSelect: {
                                        scheduler.stopSoundPreview()
                                        settings.alarmSound = sound
                                    },
                                    onPreview: {
                                        if scheduler.previewingSound == sound {
                                            scheduler.stopSoundPreview()
                                        } else {
                                            scheduler.previewSound(sound)
                                        }
                                    }
                                )
                                .listRowBackground(Theme.boardDark)
                            }
                        } header: {
                            Text(family.rawValue)
                                .font(AppTypography.emphasis)
                                .foregroundStyle(Theme.chalkFaded)
                                .textCase(nil)
                        }
                    }
                    Section {
                        Text("Sound V2 refreshes Bell and Buzz. Classic becomes Roll Call; Chime is unchanged. Check a scheduled alarm on your phone before relying on a new sound. Scheduled volume follows the system's controls, not this preview.")
                            .font(AppTypography.body)
                            .foregroundStyle(Theme.chalkFaded)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Alarm Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Theme.chalkYellow)
                        .accessibilityIdentifier("soundpicker.done")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let sound = scheduler.previewingSound {
                    Button {
                        scheduler.stopSoundPreview()
                    } label: {
                        Label("Stop preview: \(sound.label)", systemImage: "stop.fill")
                            .font(AppTypography.emphasis)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .foregroundStyle(Theme.boardDark)
                            .background(Theme.chalkYellow)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("soundpicker.stop-preview")
                }
            }
        }
        .colorScheme(settings.activeTheme.colorScheme)
        .onDisappear { scheduler.stopSoundPreview() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { scheduler.stopSoundPreview() }
        }
    }
}

private struct SoundChoiceRow: View {
    let sound: AlarmSound
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Theme.chalkYellow : Theme.chalkFaded)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(sound.label)
                            .font(AppTypography.emphasis)
                            .foregroundStyle(Theme.chalk)
                        Text(sound.detail)
                            .font(AppTypography.body)
                            .foregroundStyle(Theme.chalkFaded)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(sound.label)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint(sound.detail)
            .accessibilityIdentifier("sound.select.\(sound.rawValue)")

            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                    .frame(minWidth: 44, minHeight: 44)
                    .foregroundStyle(Theme.chalkYellow)
                    .background(Theme.board, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Stop preview of \(sound.label)" : "Preview \(sound.label)")
            .accessibilityIdentifier("sound.preview.\(sound.rawValue)")
        }
        .padding(.vertical, 8)
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
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalk)
                    Text(theme == .highContrast ? "Maximum separation" : theme == .retro ? "Sharper LCD contrast" : "Accessible palette")
                        .font(AppTypography.body)
                        .foregroundColor(Theme.chalkFaded)
                }

                Spacer(minLength: 12)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.chalkYellow)
                        .font(AppTypography.title)
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
