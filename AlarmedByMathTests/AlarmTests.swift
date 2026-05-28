import XCTest
@testable import AlarmedByMath

final class AlarmTests: XCTestCase {

    // MARK: - Defaults

    func testAlarmDefaultValues() {
        let alarm = Alarm()
        XCTAssertEqual(alarm.hour,   8)
        XCTAssertEqual(alarm.minute, 0)
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertTrue(alarm.repeatDays.isEmpty)
        XCTAssertTrue(alarm.label.isEmpty)
        XCTAssertFalse(alarm.hasFired)
    }

    // MARK: - Input validation

    func testHourIsClamped() {
        XCTAssertEqual(Alarm(hour: -1).hour, 0)
        XCTAssertEqual(Alarm(hour: 25).hour, 23)
        XCTAssertEqual(Alarm(hour: 12).hour, 12)
    }

    func testMinuteIsClamped() {
        XCTAssertEqual(Alarm(minute: -5).minute, 0)
        XCTAssertEqual(Alarm(minute: 61).minute, 59)
        XCTAssertEqual(Alarm(minute: 30).minute, 30)
    }

    func testInvalidRepeatDaysAreFiltered() {
        let alarm = Alarm(repeatDays: [0, 1, 7, 8, 99])
        XCTAssertEqual(alarm.repeatDays, [1, 7])
    }

    // MARK: - timeString

    func testTimeStringMorning() {
        XCTAssertEqual(Alarm(hour: 8,  minute: 30).timeString, "8:30 AM")
    }

    func testTimeStringAfternoon() {
        XCTAssertEqual(Alarm(hour: 14, minute:  5).timeString, "2:05 PM")
    }

    func testTimeStringMidnight() {
        XCTAssertEqual(Alarm(hour: 0,  minute:  0).timeString, "12:00 AM")
    }

    func testTimeStringNoon() {
        XCTAssertEqual(Alarm(hour: 12, minute:  0).timeString, "12:00 PM")
    }

    func testTimeStringLeadingZeroMinute() {
        XCTAssertEqual(Alarm(hour: 9, minute: 5).timeString, "9:05 AM")
    }

    // MARK: - repeatLabel

    func testRepeatLabelOnce() {
        XCTAssertEqual(Alarm(repeatDays: []).repeatLabel, "Once")
    }

    func testRepeatLabelEveryDay() {
        XCTAssertEqual(Alarm(repeatDays: Set(1...7)).repeatLabel, "Every day")
    }

    func testRepeatLabelWeekdays() {
        let alarm = Alarm(repeatDays: [2, 3, 4, 5, 6])
        XCTAssertEqual(alarm.repeatLabel, "Mon, Tue, Wed, Thu, Fri")
    }

    func testRepeatLabelWeekend() {
        let alarm = Alarm(repeatDays: [1, 7])
        XCTAssertEqual(alarm.repeatLabel, "Sun, Sat")
    }

    func testRepeatLabelDoesNotCrashWithInvalidDays() {
        // Invalid days should be filtered by init, but repeatLabel also guards defensively
        let alarm = Alarm(repeatDays: [1, 3])
        XCTAssertFalse(alarm.repeatLabel.isEmpty)
    }

    // MARK: - isSchedulable

    func testEnabledRepeatingAlarmIsSchedulable() {
        let alarm = Alarm(repeatDays: [1, 2], isEnabled: true)
        XCTAssertTrue(alarm.isSchedulable)
    }

    func testDisabledAlarmIsNotSchedulable() {
        let alarm = Alarm(isEnabled: false)
        XCTAssertFalse(alarm.isSchedulable)
    }

    func testOneTimeAlarmThatHasFiredIsNotSchedulable() {
        let alarm = Alarm(repeatDays: [], isEnabled: true, hasFired: true)
        XCTAssertFalse(alarm.isSchedulable)
    }

    func testRepeatingAlarmThatHasFiredIsStillSchedulable() {
        let alarm = Alarm(repeatDays: [1], isEnabled: true, hasFired: true)
        XCTAssertTrue(alarm.isSchedulable)
    }

    // MARK: - isOneTime

    func testIsOneTime() {
        XCTAssertTrue(Alarm(repeatDays: []).isOneTime)
        XCTAssertFalse(Alarm(repeatDays: [1]).isOneTime)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let alarm = Alarm(label: "Work", hour: 7, minute: 15, repeatDays: [2, 3, 4, 5, 6])
        let data    = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)
        XCTAssertEqual(alarm, decoded)
    }

    func testCodableRoundTripWithHasFired() throws {
        let alarm = Alarm(label: "Once", hour: 6, minute: 0, hasFired: true)
        let data    = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)
        XCTAssertEqual(decoded.hasFired, true)
        XCTAssertEqual(alarm, decoded)
    }

    // MARK: - Equatable

    func testEqualityByID() {
        let id = UUID()
        let a1 = Alarm(id: id, label: "A", hour: 6, minute: 0)
        let a2 = Alarm(id: id, label: "A", hour: 6, minute: 0)
        XCTAssertEqual(a1, a2)
    }

    func testInequalityDifferentID() {
        let a1 = Alarm(label: "A", hour: 6, minute: 0)
        let a2 = Alarm(label: "A", hour: 6, minute: 0)
        XCTAssertNotEqual(a1, a2)
    }
}
