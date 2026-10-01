import XCTest
import AlarmKit
@testable import AlarmedByMath

final class AlarmScheduleTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private let daily = Set(1...7)

    func testSpringForwardSkipsNonexistentDailyTime() {
        let schedule = AlarmSchedule(hour: 2, minute: 30, repeatDays: daily)
        XCTAssertEqual(
            schedule.nextOccurrence(after: date("2026-03-08T00:00:00-05:00"), calendar: calendar("America/New_York")),
            date("2026-03-09T02:30:00-04:00")
        )
    }

    func testSpringForwardSkipsMissingWeeklyOccurrenceWithoutChangingWeekday() {
        let schedule = AlarmSchedule(hour: 2, minute: 30, repeatDays: [1])
        XCTAssertEqual(
            schedule.nextOccurrence(after: date("2026-03-08T00:00:00-05:00"), calendar: calendar("America/New_York")),
            date("2026-03-15T02:30:00-04:00")
        )
    }

    func testFallBackChoosesTheFirstOccurrenceOnly() {
        let schedule = AlarmSchedule(hour: 1, minute: 30, repeatDays: daily)
        let zone = calendar("America/New_York")
        XCTAssertEqual(schedule.nextOccurrence(after: date("2026-11-01T00:00:00-04:00"), calendar: zone),
                       date("2026-11-01T01:30:00-04:00"))
        XCTAssertEqual(schedule.nextOccurrence(after: date("2026-11-01T01:45:00-04:00"), calendar: zone),
                       date("2026-11-02T01:30:00-05:00"))
        XCTAssertEqual(schedule.nextOccurrence(after: date("2026-11-01T01:30:00-04:00"), calendar: zone),
                       date("2026-11-02T01:30:00-05:00"))
    }

    func testOneTimeFallBackDoesNotMoveToTheSecondClockOccurrence() {
        let schedule = AlarmSchedule(hour: 1, minute: 30, repeatDays: [],
                                     oneTimeDay: AlarmDay(year: 2026, month: 11, day: 1))
        XCTAssertNil(schedule.nextOccurrence(after: date("2026-11-01T01:45:00-04:00"),
                                            calendar: calendar("America/New_York")))
    }

    func testHalfHourDaylightSavingGapIsAlsoSkipped() {
        let schedule = AlarmSchedule(hour: 2, minute: 15, repeatDays: daily)
        XCTAssertEqual(
            schedule.nextOccurrence(after: date("2026-10-04T01:59:00+10:30"), calendar: calendar("Australia/Lord_Howe")),
            date("2026-10-05T02:15:00+11:00")
        )
    }

    func testSkippedCivilDayDoesNotShiftAWeeklyAlarmToSaturday() {
        let schedule = AlarmSchedule(hour: 7, minute: 0, repeatDays: [6])
        let zone = calendar("Pacific/Apia")
        XCTAssertEqual(schedule.nextOccurrence(after: date("2011-12-29T23:00:00-10:00"), calendar: zone),
                       date("2012-01-06T07:00:00+14:00"))
        XCTAssertNil(schedule.occurrence(on: AlarmDay(year: 2011, month: 12, day: 30), calendar: zone))
    }

    func testMidnightAndLeapDayStayInTheFuture() {
        let schedule = AlarmSchedule(hour: 0, minute: 0, repeatDays: daily)
        let zone = calendar("UTC")
        XCTAssertEqual(schedule.nextOccurrence(after: date("2026-12-31T23:59:59Z"), calendar: zone),
                       date("2027-01-01T00:00:00Z"))
        XCTAssertEqual(schedule.nextOccurrence(after: date("2028-02-28T23:59:59Z"), calendar: zone),
                       date("2028-02-29T00:00:00Z"))
        XCTAssertEqual(schedule.nextOccurrence(after: date("2028-02-29T00:00:00Z"), calendar: zone),
                       date("2028-03-01T00:00:00Z"))
    }

    func testWeeklySearchNeverReturnsTheJustPassedSecond() {
        let schedule = AlarmSchedule(hour: 7, minute: 0, repeatDays: [4])
        let reference = date("2026-09-30T07:00:00Z").addingTimeInterval(0.25)
        XCTAssertEqual(schedule.nextOccurrence(after: reference, calendar: calendar("UTC")),
                       date("2026-10-07T07:00:00Z"))
    }

    func testTravelFollowsLocalTimeForRepeatingAndBoundOneTimeAlarms() {
        let reference = date("2026-09-30T10:00:00Z")
        for schedule in [
            AlarmSchedule(hour: 7, minute: 0, repeatDays: daily),
            AlarmSchedule(hour: 7, minute: 0, repeatDays: [], oneTimeDay: AlarmDay(year: 2026, month: 9, day: 30))
        ] {
            XCTAssertEqual(schedule.nextOccurrence(after: reference, calendar: calendar("America/New_York")),
                           date("2026-09-30T11:00:00Z"))
            XCTAssertEqual(schedule.nextOccurrence(after: reference, calendar: calendar("America/Los_Angeles")),
                           date("2026-09-30T14:00:00Z"))
        }
    }

    func testChangingPreferredCalendarDoesNotReinterpretStoredGregorianDay() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let schedule = AlarmSchedule(hour: 7, minute: 0, repeatDays: [],
                                     oneTimeDay: AlarmDay(year: 2026, month: 10, day: 1))
        XCTAssertEqual(schedule.nextOccurrence(after: date("2026-09-30T23:00:00+07:00"), calendar: buddhist),
                       date("2026-10-01T07:00:00+07:00"))
    }

    func testInvalidDaysAndTimesDoNotBecomeDailyAlarms() {
        let now = date("2026-09-30T00:00:00Z")
        XCTAssertNil(AlarmSchedule(hour: 7, minute: 0, repeatDays: [0, 8]).nextOccurrence(after: now))
        XCTAssertNil(AlarmSchedule(hour: 25, minute: 0, repeatDays: daily).nextOccurrence(after: now))
        XCTAssertNil(AlarmSchedule(hour: 7, minute: 60, repeatDays: daily).nextOccurrence(after: now))
    }
}

final class BoundOneTimeAlarmTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var now: Date!
    private var zone: Calendar!

    override func setUp() {
        super.setUp()
        suite = "AlarmedByMath.calendar-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        now = ISO8601DateFormatter().date(from: "2026-09-30T23:30:00Z")!
        zone = Calendar(identifier: .gregorian)
        zone.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func store() -> AlarmStore {
        AlarmStore(nowProvider: { self.now }, calendarProvider: { self.zone }, defaults: defaults)
    }

    func testNewOneTimeAlarmBindsTomorrowAndDoesNotReviveAfterItsDay() {
        let alarms = store()
        let alarm = Alarm(hour: 7, minute: 0)
        alarms.add(alarm)
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 10, day: 1))
        XCTAssertTrue(alarms.alarms[0].isEnabled)
        now = ISO8601DateFormatter().date(from: "2026-10-01T00:30:00Z")!
        XCTAssertNotNil(store().alarmForScheduling(id: alarm.id))
        now = ISO8601DateFormatter().date(from: "2026-10-02T00:30:00Z")!
        let reloaded = store()
        XCTAssertFalse(reloaded.alarms[0].isEnabled)
        XCTAssertTrue(reloaded.alarms[0].hasFired)
        XCTAssertNil(reloaded.nextAlarmDate)
    }

    func testOnlyExplicitReenableOrTimeChangeRearmsAnExpiredAlarm() {
        let alarms = store()
        let alarm = Alarm(hour: 7, minute: 0, hasFired: true,
                          oneTimeDay: AlarmDay(year: 2026, month: 9, day: 30))
        alarms.add(alarm)
        var edited = alarms.alarms[0]
        edited.label = "Renamed, not rearmed"
        alarms.update(edited)
        XCTAssertFalse(alarms.alarms[0].isEnabled)
        alarms.toggle(alarms.alarms[0])
        XCTAssertTrue(alarms.alarms[0].isEnabled)
        XCTAssertFalse(alarms.alarms[0].hasFired)
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 10, day: 1))
    }

    func testEditingLabelDoesNotPushABoundAlarmToAnotherDay() {
        let alarms = store()
        alarms.add(Alarm(hour: 23, minute: 45))
        now = ISO8601DateFormatter().date(from: "2026-10-01T00:30:00Z")!
        var edited = alarms.alarms[0]
        edited.label = "Only the label changed"
        alarms.update(edited)
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 9, day: 30))
        XCTAssertFalse(alarms.alarms[0].isEnabled)
    }

    func testLegacyMigrationExpiresPastTimeInsteadOfRearmingItTomorrow() throws {
        let old = Alarm(hour: 7, minute: 0)
        defaults.set(try JSONEncoder().encode([old]), forKey: "saved_alarms")
        let alarms = store()
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 9, day: 30))
        XCTAssertFalse(alarms.alarms[0].isEnabled)
        XCTAssertTrue(alarms.alarms[0].hasFired)
    }

    func testProtectedRingingAlarmIsNotExpiredByEntitlementRefresh() {
        let alarms = store()
        let alarm = Alarm(hour: 23, minute: 45)
        alarms.add(alarm)
        now = ISO8601DateFormatter().date(from: "2026-10-01T00:30:00Z")!
        alarms.applyEntitlements(excludingIDs: [alarm.id])
        XCTAssertTrue(alarms.alarms[0].isEnabled)
        XCTAssertFalse(alarms.alarms[0].hasFired)
        alarms.markOneTimeAlarmFired(id: alarm.id)
        XCTAssertFalse(alarms.alarms[0].isEnabled)
        XCTAssertTrue(alarms.alarms[0].hasFired)
    }

    func testCountdownUsesTheInjectedClockAndRoundsUp() {
        let alarms = store()
        alarms.add(Alarm(hour: 23, minute: 45))
        XCTAssertEqual(alarms.nextAlarmLabel, "in 15m")
        now = now.addingTimeInterval(1)
        XCTAssertEqual(alarms.nextAlarmLabel, "in 15m")
        now = now.addingTimeInterval(60)
        XCTAssertEqual(alarms.nextAlarmLabel, "in 14m")
    }

    func testArmingDuringSpringGapChoosesTheNextValidDay() {
        now = ISO8601DateFormatter().date(from: "2026-03-08T00:00:00-05:00")!
        zone.timeZone = TimeZone(identifier: "America/New_York")!
        let alarms = store()
        alarms.add(Alarm(hour: 2, minute: 30))
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 3, day: 9))
        XCTAssertEqual(alarms.nextAlarmDate, ISO8601DateFormatter().date(from: "2026-03-09T02:30:00-04:00"))
    }

    func testBoundOneTimeDaySurvivesCodingAndDuplicateDraftDoesNotReuseIt() throws {
        let alarms = store()
        alarms.add(Alarm(hour: 7, minute: 0))
        let original = alarms.alarms[0]
        let decoded = try JSONDecoder().decode(Alarm.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.oneTimeDay, original.oneTimeDay)
        XCTAssertNil(original.duplicateDraft().oneTimeDay)
    }

    func testChangingTimeZoneKeepsOneTimeLocalDayAndHour() {
        now = ISO8601DateFormatter().date(from: "2026-09-30T10:00:00Z")!
        zone.timeZone = TimeZone(identifier: "America/New_York")!
        let alarms = store()
        alarms.add(Alarm(hour: 7, minute: 0))
        XCTAssertEqual(alarms.nextAlarmDate, ISO8601DateFormatter().date(from: "2026-09-30T11:00:00Z"))
        zone.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(alarms.nextAlarmDate, ISO8601DateFormatter().date(from: "2026-09-30T14:00:00Z"))
        alarms.markOneTimeAlarmFired(id: alarms.alarms[0].id)
        XCTAssertNil(alarms.nextAlarmDate)
    }

    func testTravelPastPlannedTimeExpiresWithoutMovingToTomorrow() {
        now = ISO8601DateFormatter().date(from: "2026-09-30T10:00:00Z")!
        zone.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let alarms = store()
        alarms.add(Alarm(hour: 7, minute: 0))
        let id = alarms.alarms[0].id
        zone.timeZone = TimeZone(identifier: "Europe/London")!
        alarms.applyEntitlements()
        XCTAssertFalse(alarms.alarms[0].isEnabled)
        XCTAssertTrue(alarms.alarms[0].hasFired)
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 9, day: 30))
        XCTAssertNil(alarms.alarmForScheduling(id: id))
        // Coming back must not resurrect an alarm that already expired.
        zone.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        alarms.applyEntitlements()
        XCTAssertNil(alarms.nextAlarmDate)
    }

    func testArmingBetweenFallBackCopiesUsesTomorrowNotTheSecondCopy() {
        now = ISO8601DateFormatter().date(from: "2026-11-01T01:45:00-04:00")!
        zone.timeZone = TimeZone(identifier: "America/New_York")!
        let alarms = store()
        alarms.add(Alarm(hour: 1, minute: 30))
        XCTAssertEqual(alarms.alarms[0].oneTimeDay, AlarmDay(year: 2026, month: 11, day: 2))
        XCTAssertEqual(alarms.nextAlarmDate, ISO8601DateFormatter().date(from: "2026-11-02T01:30:00-05:00"))
    }

    func testChangingEnabledOneTimeToRepeatClearsItsBoundDay() {
        let alarms = store()
        alarms.add(Alarm(hour: 7, minute: 0))
        var edited = alarms.alarms[0]
        edited.repeatDays = [2, 3, 4, 5, 6]
        alarms.update(edited)
        XCTAssertNil(alarms.alarms[0].oneTimeDay)
        XCTAssertFalse(alarms.alarms[0].hasFired)
        XCTAssertNotNil(alarms.nextAlarmDate)
    }

    func testObservedOneShotStaysConsumedWhenTheClockMovesBack() {
        let alarms = store()
        alarms.add(Alarm(hour: 7, minute: 0))
        let id = alarms.alarms[0].id
        alarms.markOneTimeAlarmFired(id: id)
        now = ISO8601DateFormatter().date(from: "2026-09-30T06:00:00Z")!
        alarms.applyEntitlements()
        XCTAssertTrue(alarms.alarms[0].hasFired)
        XCTAssertFalse(alarms.alarms[0].isEnabled)
        XCTAssertNil(store().alarmForScheduling(id: id))
    }

    func testObservedRepeatingAlarmKeepsItsFutureSchedule() {
        let alarms = store()
        alarms.add(Alarm(hour: 7, minute: 0, repeatDays: [2, 4, 6]))
        let id = alarms.alarms[0].id
        let next = alarms.nextAlarmDate
        alarms.markOneTimeAlarmFired(id: id)
        XCTAssertTrue(alarms.alarms[0].isEnabled)
        XCTAssertFalse(alarms.alarms[0].hasFired)
        XCTAssertEqual(alarms.nextAlarmDate, next)
    }
}

final class WidgetScheduleTests: XCTestCase {
    private func snapshot(_ upcoming: [WidgetSharedStore.UpcomingAlarm]) -> WidgetSharedStore.Snapshot {
        WidgetSharedStore.Snapshot(isPremiumUnlocked: true, upcomingAlarms: upcoming, currentStreak: 0,
                                   theme: .placeholder, config: .placeholder)
    }

    func testAppSchedulerAndWidgetResolveTheSameDateAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = ISO8601DateFormatter().date(from: "2026-03-08T00:00:00-05:00")!
        let alarm = Alarm(hour: 2, minute: 30, repeatDays: Set(1...7))
        let expected = ISO8601DateFormatter().date(from: "2026-03-09T02:30:00-04:00")!
        let suite = "AlarmedByMath.widget-calendar.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AlarmStore(nowProvider: { now }, calendarProvider: { calendar }, defaults: defaults)
        store.add(alarm)
        let upcoming = WidgetSync.upcomingAlarms(from: store.alarms, now: now, calendar: calendar)
        XCTAssertEqual(store.nextAlarmDate, expected)
        XCTAssertEqual(AlarmScheduler.nextFireDate(for: store.alarms[0], now: now, calendar: calendar), expected)
        XCTAssertEqual(snapshot(upcoming).visibleAlarms(after: now, limit: 1, calendar: calendar).first?.date, expected)
    }

    func testWidgetRecomputesRepeatsAfterTheCachedOccurrencePasses() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-09-30T06:00:00Z")!
        let alarm = Alarm(label: "Daily", hour: 7, minute: 0, repeatDays: Set(1...7))
        let cached = snapshot(WidgetSync.upcomingAlarms(from: [alarm], now: now, calendar: calendar))
        let later = ISO8601DateFormatter().date(from: "2026-09-30T08:00:00Z")!
        XCTAssertEqual(cached.visibleAlarms(after: later, limit: 1, calendar: calendar).first?.date,
                       ISO8601DateFormatter().date(from: "2026-10-01T07:00:00Z"))
    }

    func testWidgetRetainsLaterAlarmsBeyondTheOldSixItemBuffer() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-09-30T00:00:00Z")!
        let alarms = (1...8).map {
            Alarm(label: "\($0)", hour: $0, minute: 0, oneTimeDay: AlarmDay(year: 2026, month: 9, day: 30))
        }
        let cached = snapshot(WidgetSync.upcomingAlarms(from: alarms, now: now, calendar: calendar))
        XCTAssertEqual(cached.upcomingAlarms.count, 8)
        let later = ISO8601DateFormatter().date(from: "2026-09-30T06:30:00Z")!
        XCTAssertEqual(cached.visibleAlarms(after: later, limit: 3, calendar: calendar).map(\.label), ["7", "8"])
    }

    func testOldSnapshotEntryStillDecodesAndExpires() throws {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let data = try JSONSerialization.data(withJSONObject: ["date": date.timeIntervalSinceReferenceDate, "label": "Legacy"])
        let entry = try JSONDecoder().decode(WidgetSharedStore.UpcomingAlarm.self, from: data)
        XCTAssertNil(entry.schedule)
        XCTAssertEqual(snapshot([entry]).visibleAlarms(after: date.addingTimeInterval(-1), limit: 1), [entry])
        XCTAssertTrue(snapshot([entry]).visibleAlarms(after: date, limit: 1).isEmpty)
    }

    func testWidgetPreservesFixedOneShotUntilTheAppReschedulesAfterTravel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = ISO8601DateFormatter().date(from: "2026-09-30T10:00:00Z")!
        let alarms = [
            Alarm(label: "One time", hour: 7, minute: 0, oneTimeDay: AlarmDay(year: 2026, month: 9, day: 30)),
            Alarm(label: "Repeat", hour: 8, minute: 0, repeatDays: Set(1...7))
        ]
        let original = snapshot(WidgetSync.upcomingAlarms(from: alarms, now: now, calendar: calendar))
        let cached = try JSONDecoder().decode(WidgetSharedStore.Snapshot.self, from: JSONEncoder().encode(original))
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(cached.visibleAlarms(after: now, limit: 2, calendar: calendar).map(\.date), [
            ISO8601DateFormatter().date(from: "2026-09-30T11:00:00Z")!,
            ISO8601DateFormatter().date(from: "2026-09-30T15:00:00Z")!
        ])
        let refreshed = snapshot(WidgetSync.upcomingAlarms(from: alarms, now: now, calendar: calendar))
        XCTAssertEqual(refreshed.visibleAlarms(after: now, limit: 2, calendar: calendar).map(\.date), [
            ISO8601DateFormatter().date(from: "2026-09-30T14:00:00Z")!,
            ISO8601DateFormatter().date(from: "2026-09-30T15:00:00Z")!
        ])
    }
}

@available(iOS 26.1, *)
final class NativeCalendarConfigurationTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    private var zone: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    func testAlarmKitOneShotCarriesItsExactBoundDay() throws {
        let alarm = Alarm(hour: 7, minute: 0, oneTimeDay: AlarmDay(year: 2026, month: 10, day: 2))
        let schedule = try AlarmKitScheduler.systemSchedule(for: alarm, now: date("2026-10-01T06:00:00-04:00"), calendar: zone)
        XCTAssertEqual(schedule, .fixed(date("2026-10-02T07:00:00-04:00")))
    }

    func testAlarmKitOneShotCarriesTheFirstFallBackInstant() throws {
        let alarm = Alarm(hour: 1, minute: 30, oneTimeDay: AlarmDay(year: 2026, month: 11, day: 1))
        let now = date("2026-11-01T00:00:00-04:00")
        XCTAssertEqual(try AlarmKitScheduler.systemSchedule(for: alarm, now: now, calendar: zone),
                       .fixed(date("2026-11-01T01:30:00-04:00")))
    }

    func testExpiredOrDisabledOneShotCannotBeReplacedWithTomorrow() {
        let expired = Alarm(hour: 7, minute: 0, oneTimeDay: AlarmDay(year: 2026, month: 9, day: 30))
        let now = date("2026-10-01T06:00:00-04:00")
        XCTAssertThrowsError(try AlarmKitScheduler.systemSchedule(for: expired, now: now, calendar: zone))
        let disabled = Alarm(hour: 7, minute: 0, isEnabled: false, oneTimeDay: AlarmDay(year: 2026, month: 10, day: 2))
        XCTAssertThrowsError(try AlarmKitScheduler.systemSchedule(for: disabled, now: now, calendar: zone))
    }

    func testRepeatingAlarmRetainsNativeWeeklyLocalClockSchedule() throws {
        let alarm = Alarm(hour: 7, minute: 0, repeatDays: [2, 4])
        XCTAssertEqual(try AlarmKitScheduler.systemSchedule(for: alarm, now: date("2026-09-30T06:00:00-04:00"), calendar: zone),
                       .relative(.init(time: .init(hour: 7, minute: 0), repeats: .weekly([.monday, .wednesday]))))
    }

    func testFallbackTriggerKeepsFoldAndMidnightInstantsUnambiguous() throws {
        for instant in [
            date("2026-11-01T01:30:00-04:00"),
            date("2026-11-01T01:30:00-05:00"),
            date("2027-01-01T00:00:00+13:00")
        ] {
            let trigger = AlarmScheduler.fixedNotificationTrigger(at: instant)
            XCTAssertFalse(trigger.repeats)
            XCTAssertEqual(trigger.dateComponents.timeZone?.secondsFromGMT(for: instant), 0)
            let calendar = try XCTUnwrap(trigger.dateComponents.calendar)
            XCTAssertEqual(calendar.identifier, .gregorian)
            XCTAssertEqual(calendar.date(from: trigger.dateComponents), instant)
        }
    }

    func testFallbackSystemComputesTheExactFutureTriggerDate() {
        let future = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 86_400)
        XCTAssertEqual(AlarmScheduler.fixedNotificationTrigger(at: future).nextTriggerDate(), future)
    }
}
