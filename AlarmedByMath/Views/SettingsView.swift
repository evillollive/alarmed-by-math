import SwiftUI
import AudioToolbox

struct SettingsView: View {
    @EnvironmentObject var settings:  SettingsStore
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
        .colorScheme(settings.activeTheme.colorScheme)
    }

    // MARK: - Theme section

    private var themeSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Theme")
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

    // MARK: - Sound section

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
                            // Play a preview when tapped
                            AudioServicesPlaySystemSound(sound.systemSoundID)
                        }
                    }
                }
                Text("Tap to preview")
                    .font(.caption2)
                    .foregroundColor(Theme.chalkFaded)
            }
        }
    }

    // MARK: - Test alarm section

    private var testAlarmSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Test Alarm")
                Text("Triggers the ringing screen immediately so you can preview the sound and math challenge. Plays even if your phone is on silent.")
                    .font(.caption)
                    .foregroundColor(Theme.chalkFaded)
                Button {
                    dismiss()
                    // Small delay so the sheet finishes dismissing before the full-screen cover appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        scheduler.startRinging(alarmID: "test", preview: true)
                    }
                } label: {
                    HStack {
                        Image(systemName: "alarm.fill")
                        Text("Trigger Test Alarm")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.chalkRed)
                    .foregroundColor(Theme.chalk)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared helpers

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
}

// MARK: - ThemeRow

struct ThemeRow: View {
    let theme:      AppTheme
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Color swatches showing what the theme looks like
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.colors.board)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.colors.chalkYellow)
                        .frame(width: 22, height: 22)
                }

                Text(theme.label)
                    .font(.system(.body, design: Theme.fontDesign))
                    .foregroundColor(Theme.chalk)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.chalkYellow)
                        .font(.title3)
                }
            }
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
    }
}
