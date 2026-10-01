import Foundation

/// A local Gregorian day, independent of the time zone used to view it.
struct AlarmDay: Codable, Equatable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar) {
        let calendar = AlarmSchedule.clockCalendar(calendar)
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
    }
}

/// Foundation-only planning rules shared by the app and widget.
struct AlarmSchedule: Codable, Equatable {
    let hour: Int
    let minute: Int
    let repeatDays: Set<Int>
    var oneTimeDay: AlarmDay?

    static func clockCalendar(_ source: Calendar) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        return calendar
    }

    func nextOccurrence(after reference: Date, calendar source: Calendar = .current) -> Date? {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        let calendar = Self.clockCalendar(source)
        if repeatDays.isEmpty {
            let day = oneTimeDay ?? AlarmDay(date: reference, calendar: calendar)
            guard let date = occurrence(on: day, calendar: calendar), date > reference else { return nil }
            return date
        }
        let validDays = repeatDays.filter { (1...7).contains($0) }
        guard !validDays.isEmpty else { return nil }
        let start = calendar.startOfDay(for: reference)
        // Two weeks also cover a selected weekday lost to a skipped civil day.
        for offset in 0...14 {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: start),
                  validDays.contains(calendar.component(.weekday, from: dayDate)),
                  let date = occurrence(on: AlarmDay(date: dayDate, calendar: calendar), calendar: calendar),
                  date > reference else { continue }
            return date
        }
        return nil
    }

    func occurrence(on day: AlarmDay, calendar source: Calendar = .current) -> Date? {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        let calendar = Self.clockCalendar(source)
        guard let noon = calendar.date(from: DateComponents(
            year: day.year, month: day.month, day: day.day, hour: 12
        )), AlarmDay(date: noon, calendar: calendar) == day,
              let interval = calendar.dateInterval(of: .day, for: noon),
              let candidate = calendar.nextDate(
                after: interval.start.addingTimeInterval(-1),
                matching: DateComponents(hour: hour, minute: minute, second: 0),
                matchingPolicy: .strict,
                repeatedTimePolicy: .first
              ), candidate < interval.end else { return nil }
        return candidate
    }

    static func nextOneTimeDay(hour: Int, minute: Int, after reference: Date, calendar: Calendar = .current) -> AlarmDay? {
        let schedule = AlarmSchedule(hour: hour, minute: minute, repeatDays: Set(1...7))
        guard let date = schedule.nextOccurrence(after: reference, calendar: calendar) else { return nil }
        return AlarmDay(date: date, calendar: calendar)
    }
}
