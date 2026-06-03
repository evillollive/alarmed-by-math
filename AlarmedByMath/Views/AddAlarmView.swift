import SwiftUI
import MediaPlayer

struct AddAlarmView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @EnvironmentObject var settings:   SettingsStore
    @Environment(\.dismiss) var dismiss

    let alarmToEdit: Alarm?

    @State private var selectedTime:      Date
    @State private var label:             String
    @State private var repeatDays:        Set<Int>
    @State private var difficulty:        Difficulty
    @State private var problemCount:      Int
    @State private var songPersistentID:  String?
    @State private var songTitle:         String?
    @State private var volume:            Float
    @State private var snoozeDuration:    Int
    @State private var keepRinging:       Bool
    @State private var showingMusicPicker = false

    private let daySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private var whizLocked: Bool { !settings.allowsWhizDifficulty }

    // Designated init, pre-fills fields when editing an existing alarm
    init(alarmToEdit: Alarm? = nil) {
        self.alarmToEdit = alarmToEdit
        if let alarm = alarmToEdit {
            var components    = DateComponents()
            components.hour   = alarm.hour
            components.minute = alarm.minute
            let date = Calendar.current.date(from: components) ?? Date()
            _selectedTime     = State(initialValue: date)
            _label            = State(initialValue: alarm.label)
            _repeatDays       = State(initialValue: alarm.repeatDays)
            _difficulty       = State(initialValue: alarm.difficulty)
            _problemCount     = State(initialValue: alarm.problemCount)
            _songPersistentID = State(initialValue: alarm.songPersistentID)
            _songTitle        = State(initialValue: alarm.songTitle)
            _volume           = State(initialValue: alarm.volume)
            _snoozeDuration   = State(initialValue: alarm.snoozeDuration)
            _keepRinging      = State(initialValue: alarm.keepRinging)
        } else {
            _selectedTime     = State(initialValue: Date())
            _label            = State(initialValue: "")
            _repeatDays       = State(initialValue: [])
            _difficulty       = State(initialValue: .medium)
            _problemCount     = State(initialValue: 1)
            _songPersistentID = State(initialValue: nil)
            _songTitle        = State(initialValue: nil)
            _volume           = State(initialValue: 1.0)
            _snoozeDuration   = State(initialValue: 5)
            _keepRinging      = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.board.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Time picker
                        chalkCard {
                            DatePicker(
                                "",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }

                        // Label
                        chalkCard {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("Label")
                                TextField("Alarm label (optional)", text: $label)
                                    .foregroundColor(Theme.chalk)
                                    .font(.system(.body, design: Theme.fontDesign))
                            }
                        }

                        // Difficulty
                        chalkCard {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Difficulty")
                                HStack(spacing: 6) {
                                    ForEach(Difficulty.allCases, id: \.self) { level in
                                        let isLockedWhiz = level == .whiz && whizLocked
                                        DayToggleButton(
                                            title: isLockedWhiz ? "\(level.label) 🔒" : level.label,
                                            isSelected: difficulty == level
                                        ) {
                                            guard !isLockedWhiz else { return }
                                            difficulty = level
                                        }
                                    }
                                }
                                if whizLocked {
                                    Text("Whiz is part of the paid tier. Unlock or restore it in Settings. Free alarms currently support up to Expert.")
                                        .font(.caption)
                                        .foregroundColor(Theme.chalkFaded)
                                }
                                if difficulty == .whiz && whizLocked {
                                    Text("This alarm will be saved as Expert until Whiz is unlocked.")
                                        .font(.caption)
                                        .foregroundColor(Theme.chalkYellow)
                                }
                            }
                        }

                        // Problems to solve
                        chalkCard {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Problems to Solve")
                                HStack {
                                    Text("\(problemCount) problem\(problemCount == 1 ? "" : "s")")
                                        .font(.system(.body, design: Theme.fontDesign))
                                        .foregroundColor(Theme.chalk)
                                    Spacer()
                                    Stepper("", value: $problemCount, in: 1...10)
                                        .labelsHidden()
                                }
                            }
                        }

                        // Alarm sound
                        if scheduler.supportsCustomSongs {
                            chalkCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    sectionHeader("Alarm Sound")
                                    Button {
                                        showingMusicPicker = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "music.note")
                                                .foregroundColor(Theme.chalkYellow)
                                            Text(songTitle ?? "Default Sound")
                                                .font(.system(.body, design: Theme.fontDesign))
                                                .foregroundColor(songTitle == nil ? Theme.chalkFaded : Theme.chalk)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(Theme.chalkFaded)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if songTitle != nil {
                                        Button("Remove Song") {
                                            songPersistentID = nil
                                            songTitle        = nil
                                        }
                                        .font(.caption)
                                        .foregroundColor(Theme.chalkRed)
                                    }
                                }
                            }
                        } else {
                            chalkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionHeader("Alarm Sound")
                                    Text(settings.allowsCustomSongs
                                         ? "Whiz is unlocked, but this iOS alarm path still uses the app sound from Settings for dependable scheduled alarms."
                                         : "Custom songs are in the paid Whiz tier, and this iOS alarm path still uses the app sound from Settings for dependable scheduled alarms.")
                                        .font(.caption)
                                        .foregroundColor(Theme.chalkFaded)
                                }
                            }
                        }

                        // Volume
                        if scheduler.supportsPerAlarmVolume {
                            chalkCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    sectionHeader("Volume")
                                    HStack(spacing: 10) {
                                        Image(systemName: "speaker.fill")
                                            .foregroundColor(Theme.chalkFaded)
                                            .font(.caption)
                                        Slider(value: $volume, in: 0.1...1.0)
                                            .tint(Theme.chalkYellow)
                                        Image(systemName: "speaker.wave.3.fill")
                                            .foregroundColor(Theme.chalkFaded)
                                            .font(.caption)
                                    }
                                }
                            }
                        } else {
                            chalkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    sectionHeader("Volume")
                                    Text("Scheduled alarms use the system alarm volume on this iOS path, so there isn't a reliable per-alarm volume control here.")
                                        .font(.caption)
                                        .foregroundColor(Theme.chalkFaded)
                                }
                            }
                        }

                        // Keep ringing
                        chalkCard {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionHeader("Keep Ringing While Solving")
                                HStack {
                                    Text("Sound keeps playing during the math challenge.")
                                        .font(.caption)
                                        .foregroundColor(Theme.chalkFaded)
                                    Spacer()
                                    Toggle("", isOn: $keepRinging)
                                        .tint(Theme.chalkYellow)
                                        .labelsHidden()
                                }
                            }
                        }

                        // Snooze duration
                        chalkCard {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Snooze Duration")
                                Text("How long before the alarm re-rings after you open the challenge.")
                                    .font(.caption)
                                    .foregroundColor(Theme.chalkFaded)
                                HStack {
                                    Text("\(snoozeDuration) minute\(snoozeDuration == 1 ? "" : "s")")
                                        .font(.system(.body, design: Theme.fontDesign))
                                        .foregroundColor(Theme.chalk)
                                    Spacer()
                                    Stepper("", value: $snoozeDuration, in: 1...60)
                                        .labelsHidden()
                                }
                            }
                        }

                        // Repeat days
                        chalkCard {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Repeat")
                                HStack(spacing: 6) {
                                    ForEach(1...7, id: \.self) { day in
                                        DayToggleButton(
                                            title: daySymbols[day - 1],
                                            isSelected: repeatDays.contains(day)
                                        ) {
                                            if repeatDays.contains(day) {
                                                repeatDays.remove(day)
                                            } else {
                                                repeatDays.insert(day)
                                            }
                                        }
                                        .accessibilityLabel("\(daySymbols[day - 1]) repeat")
                                        .accessibilityValue(repeatDays.contains(day) ? "Selected" : "Not selected")
                                        .accessibilityHint("Double tap to toggle this weekday")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(alarmToEdit == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.boardDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(settings.activeTheme.colorScheme == .light ? .light : .dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.chalkFaded)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(Theme.chalkYellow)
                        .fontWeight(.semibold)
                }
            }
        }
        .colorScheme(settings.activeTheme.colorScheme)
        .sheet(isPresented: $showingMusicPicker) {
            MediaPickerRepresentable { item in
                guard let item else { return }
                let artist = item.artist ?? ""
                let title  = item.title  ?? "Unknown"
                songTitle        = artist.isEmpty ? title : "\(artist), \(title)"
                songPersistentID = String(item.persistentID)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Helper views

    @ViewBuilder
    private func chalkCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    // MARK: - Save

    private func save() {
        let cal        = Calendar.current
        let components = cal.dateComponents([.hour, .minute], from: selectedTime)
        let hour       = components.hour   ?? 8
        let minute     = components.minute ?? 0

        let effectiveSongPersistentID = scheduler.supportsCustomSongs ? songPersistentID : nil
        let effectiveSongTitle = scheduler.supportsCustomSongs ? songTitle : nil
        let effectiveVolume: Float = scheduler.supportsPerAlarmVolume ? volume : 1.0
        let effectiveDifficulty = Difficulty.effective(
            difficulty,
            whizUnlocked: settings.allowsWhizDifficulty
        )

        if let existing = alarmToEdit {
            var updated              = existing
            updated.label            = label
            updated.hour             = hour
            updated.minute           = minute
            updated.repeatDays       = repeatDays
            updated.difficulty       = effectiveDifficulty
            updated.problemCount     = problemCount
            updated.songPersistentID = effectiveSongPersistentID
            updated.songTitle        = effectiveSongTitle
            updated.volume           = effectiveVolume
            updated.snoozeDuration   = snoozeDuration
            updated.keepRinging      = keepRinging
            scheduler.cancel(existing)
            alarmStore.update(updated)
            schedulePersistedAlarm(id: updated.id)
        } else {
            let alarm = Alarm(
                label:            label,
                hour:             hour,
                minute:           minute,
                repeatDays:       repeatDays,
                difficulty:       effectiveDifficulty,
                problemCount:     problemCount,
                songPersistentID: effectiveSongPersistentID,
                songTitle:        effectiveSongTitle,
                volume:           effectiveVolume,
                snoozeDuration:   snoozeDuration,
                keepRinging:      keepRinging
            )
            alarmStore.add(alarm)
            schedulePersistedAlarm(id: alarm.id)
        }
        dismiss()
    }

    /// Schedules the alarm using the persisted, normalized record from the store
    /// so scheduling never runs against a stale pre-save value.
    private func schedulePersistedAlarm(id: UUID) {
        guard let persisted = alarmStore.alarmForScheduling(id: id) else { return }
        scheduler.schedule(persisted)
    }
}

// MARK: - MediaPickerRepresentable

/// Wraps MPMediaPickerController so it can be presented as a SwiftUI sheet.
/// Calls `onPick` with the selected MPMediaItem (or nil if cancelled).
struct MediaPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (MPMediaItem?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems            = false
        picker.prompt                     = "Choose an alarm sound"
        picker.delegate                   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPick: (MPMediaItem?) -> Void
        init(onPick: @escaping (MPMediaItem?) -> Void) { self.onPick = onPick }

        func mediaPicker(
            _ mediaPicker: MPMediaPickerController,
            didPickMediaItems mediaItemCollection: MPMediaItemCollection
        ) {
            onPick(mediaItemCollection.items.first)
            mediaPicker.dismiss(animated: true)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            onPick(nil)
            mediaPicker.dismiss(animated: true)
        }
    }
}

// MARK: - DayToggleButton

struct DayToggleButton: View {
    let title:      String
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: Theme.fontDesign))
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Theme.chalkYellow : Theme.board)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Theme.chalkYellow : Theme.chalk.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
                .foregroundColor(isSelected ? Theme.boardDark : Theme.chalkFaded)
        }
        .buttonStyle(.plain)
    }
}
