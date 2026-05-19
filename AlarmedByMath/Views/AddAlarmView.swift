import SwiftUI

struct AddAlarmView: View {
    @EnvironmentObject var alarmStore: AlarmStore
    @EnvironmentObject var scheduler:  AlarmScheduler
    @Environment(\.dismiss) var dismiss

    @State private var selectedTime = Date()
    @State private var label        = ""
    @State private var repeatDays: Set<Int> = []

    private let daySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker(
                        "",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                Section("Label") {
                    TextField("Alarm label (optional)", text: $label)
                }

                Section("Repeat") {
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
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let cal        = Calendar.current
        let components = cal.dateComponents([.hour, .minute], from: selectedTime)
        let alarm      = Alarm(
            label:      label,
            hour:       components.hour   ?? 8,
            minute:     components.minute ?? 0,
            repeatDays: repeatDays
        )
        alarmStore.add(alarm)
        scheduler.schedule(alarm)
        dismiss()
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
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
