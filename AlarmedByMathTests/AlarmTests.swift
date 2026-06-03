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

    // MARK: - detailLabel

    func testDetailLabelWithoutName() {
        let alarm = Alarm(repeatDays: [2, 4, 6])
        XCTAssertEqual(alarm.detailLabel, "Mon, Wed, Fri")
    }

    func testDetailLabelWithNameIncludesComma() {
        let alarm = Alarm(label: "Gym", repeatDays: [2, 4, 6])
        XCTAssertEqual(alarm.detailLabel, "Gym, Mon, Wed, Fri")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let alarm = Alarm(label: "Work", hour: 7, minute: 15, repeatDays: [2, 3, 4, 5, 6])
        let data    = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)
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

@available(iOS 26.1, *)
final class AlarmKitSnoozeTests: XCTestCase {

    func testSnoozeDelayUsesMinutesInSeconds() {
        XCTAssertEqual(AlarmKitScheduler.snoozeDelay(forMinutes: 5), 300)
        XCTAssertEqual(AlarmKitScheduler.snoozeDelay(forMinutes: 12), 720)
    }

    func testSnoozeDelayClampsToOneMinuteMinimum() {
        XCTAssertEqual(AlarmKitScheduler.snoozeDelay(forMinutes: 0), 60)
        XCTAssertEqual(AlarmKitScheduler.snoozeDelay(forMinutes: -3), 60)
    }
}

final class PythagorasEasterEggTests: XCTestCase {

    func testEasterEggStaysHiddenBeforeMilestone() {
        XCTAssertNil(PythagorasEasterEggState(alarmCount: 7, dismissedCount: 7))
    }

    func testEasterEggUnlocksWithEightConfiguredAlarms() {
        let easterEgg = PythagorasEasterEggState(alarmCount: 8, dismissedCount: 0)

        XCTAssertEqual(easterEgg?.title, "Pythagoras Club")
        XCTAssertTrue(easterEgg?.message.contains("tiny theorem sticker") == true)
        XCTAssertTrue(easterEgg?.message.contains("secret proof") == true)
    }

    func testEasterEggUnlocksWithEightDismissedAlarms() {
        let easterEgg = PythagorasEasterEggState(alarmCount: 2, dismissedCount: 8)

        XCTAssertEqual(easterEgg?.title, "Proof of Wakefulness")
        XCTAssertTrue(easterEgg?.message.contains("completed alarms") == true)
        XCTAssertTrue(easterEgg?.footnote.contains("Euclid-approved") == true)
    }
}

final class RingingAlarmQueueTests: XCTestCase {

    func testPushActivatesFirstAlarmAndQueuesSecond() {
        var queue = RingingAlarmQueue()
        let first = RingingAlarmContext(alarmID: "a")
        let second = RingingAlarmContext(alarmID: "b", autoPresentMath: true)

        XCTAssertTrue(queue.push(first))
        XCTAssertFalse(queue.push(second))
        XCTAssertEqual(queue.activeAlarmID, "a")
        XCTAssertEqual(queue.queued.map(\.alarmID), ["b"])
    }

    func testPushMergesRepeatedAlarmInsteadOfDuplicatingQueueEntry() {
        var queue = RingingAlarmQueue()
        XCTAssertTrue(queue.push(RingingAlarmContext(alarmID: "a", snoozeDuration: 5)))
        XCTAssertFalse(queue.push(RingingAlarmContext(alarmID: "b", snoozeDuration: 3)))
        XCTAssertFalse(queue.push(RingingAlarmContext(alarmID: "b", snoozeDuration: 9, autoPresentMath: true)))

        XCTAssertEqual(queue.queued.count, 1)
        XCTAssertEqual(queue.queued.first?.snoozeDuration, 9)
        XCTAssertEqual(queue.queued.first?.autoPresentMath, true)
    }

    func testPopCurrentAdvancesQueuedAlarm() {
        var queue = RingingAlarmQueue()
        _ = queue.push(RingingAlarmContext(alarmID: "a"))
        _ = queue.push(RingingAlarmContext(alarmID: "b", autoPresentMath: true))

        let next = queue.popCurrent()

        XCTAssertEqual(next?.alarmID, "b")
        XCTAssertEqual(queue.activeAlarmID, "b")
        XCTAssertTrue(queue.autoPresentMath)
        XCTAssertTrue(queue.isRinging)
    }
}

final class ThemePaletteTests: XCTestCase {

    func testBodyTextContrastMeetsAA() {
        for theme in AppTheme.allCases {
            let colors = theme.colors
            XCTAssertGreaterThanOrEqual(
                colors.boardSwatch.contrastRatio(with: colors.chalkSwatch),
                4.5,
                "\(theme.label) body text contrast is below AA"
            )
            XCTAssertGreaterThanOrEqual(
                colors.boardDarkSwatch.contrastRatio(with: colors.chalkSwatch),
                4.5,
                "\(theme.label) card text contrast is below AA"
            )
        }
    }

    func testSecondaryAndAccentColorsStayReadable() {
        for theme in AppTheme.allCases {
            let colors = theme.colors
            XCTAssertGreaterThanOrEqual(
                colors.boardSwatch.contrastRatio(with: colors.chalkFadedSwatch),
                3.0,
                "\(theme.label) secondary text contrast is too low"
            )
            XCTAssertGreaterThanOrEqual(
                colors.boardSwatch.contrastRatio(with: colors.chalkYellowSwatch),
                3.0,
                "\(theme.label) yellow accent contrast is too low"
            )
            XCTAssertGreaterThanOrEqual(
                colors.boardSwatch.contrastRatio(with: colors.chalkBlueSwatch),
                3.0,
                "\(theme.label) blue accent contrast is too low"
            )
            XCTAssertGreaterThanOrEqual(
                colors.boardSwatch.contrastRatio(with: colors.chalkRedSwatch),
                3.0,
                "\(theme.label) red accent contrast is too low"
            )
        }
    }

    func testCuteThemesAreAvailable() {
        XCTAssertTrue(AppTheme.allCases.contains(.bubblegum))
        XCTAssertTrue(AppTheme.allCases.contains(.bluebird))
    }

    func testDarkAndHighContrastStayDistinct() {
        XCTAssertNotEqual(AppTheme.dark.colors.boardSwatch, AppTheme.highContrast.colors.boardSwatch)
        XCTAssertNotEqual(AppTheme.dark.colors.chalkYellowSwatch, AppTheme.highContrast.colors.chalkYellowSwatch)
    }
}

final class AlarmStoreOrderingTests: XCTestCase {
    private let storageKey = "saved_alarms"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    func testAlarmsAreSortedByTimeWhenAdded() {
        let store = AlarmStore()
        store.add(Alarm(label: "Late", hour: 9, minute: 30))
        store.add(Alarm(label: "Early", hour: 6, minute: 15))
        store.add(Alarm(label: "Mid", hour: 8, minute: 0))

        XCTAssertEqual(store.alarms.map(\.timeString), ["6:15 AM", "8:00 AM", "9:30 AM"])
    }

    func testAlarmsResortWhenTimeChanges() {
        let store = AlarmStore()
        let early = Alarm(label: "Early", hour: 6, minute: 0)
        let late = Alarm(label: "Late", hour: 10, minute: 0)
        store.add(early)
        store.add(late)

        var updatedLate = late
        updatedLate.hour = 5
        updatedLate.minute = 45
        store.update(updatedLate)

        XCTAssertEqual(store.alarms.map(\.timeString), ["5:45 AM", "6:00 AM"])
        XCTAssertEqual(store.alarms.first?.id, late.id)
    }
}

final class AlarmValidationTests: XCTestCase {
    func testNormalizationClampsInvalidValues() {
        let alarm = Alarm(
            label: String(repeating: "x", count: 120),
            hour: -4,
            minute: 88,
            repeatDays: [0, 1, 8],
            problemCount: 999,
            volume: 9.0,
            snoozeDuration: -5
        ).normalized()

        XCTAssertEqual(alarm.label.count, 80)
        XCTAssertEqual(alarm.hour, 0)
        XCTAssertEqual(alarm.minute, 59)
        XCTAssertEqual(alarm.repeatDays, [1])
        XCTAssertEqual(alarm.problemCount, 10)
        XCTAssertEqual(alarm.volume, 1.0)
        XCTAssertEqual(alarm.snoozeDuration, 1)
    }

    func testRepeatLabelIgnoresInvalidWeekdays() {
        let alarm = Alarm(repeatDays: [1, 4, 10])
        XCTAssertEqual(alarm.repeatLabel, "Sun, Wed")
    }
}

final class AlarmOneTimeFireDateTests: XCTestCase {
    func testOneTimePastAlarmDoesNotRescheduleTomorrow() {
        let cal = Calendar.current
        let now = Date()
        let oneHourAgo = cal.date(byAdding: .hour, value: -1, to: now) ?? now
        let comps = cal.dateComponents([.hour, .minute], from: oneHourAgo)
        let alarm = Alarm(hour: comps.hour ?? 0, minute: comps.minute ?? 0, repeatDays: [])

        XCTAssertNil(AlarmScheduler.nextFireDate(for: alarm))
    }

    func testOneTimeFiredAlarmHasNoNextDate() {
        let alarm = Alarm(hour: 23, minute: 59, repeatDays: [], hasFired: true)
        XCTAssertNil(AlarmScheduler.nextFireDate(for: alarm))
    }
}

final class AlarmStoreExpirationTests: XCTestCase {
    private let storageKey = "saved_alarms"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    func testOneTimePastAlarmIsExpiredAndDisabled() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let store = AlarmStore(nowProvider: { now })
        store.add(Alarm(label: "Past", hour: 7, minute: 30, repeatDays: []))

        XCTAssertEqual(store.alarms.count, 1)
        XCTAssertTrue(store.alarms[0].hasFired)
        XCTAssertFalse(store.alarms[0].isEnabled)
    }

    func testExcludedAlarmIsNotExpired() {
        let cal = Calendar.current
        let initialNow = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 6, minute: 0))!
        let expiryNow = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let store = AlarmStore(nowProvider: { initialNow })
        let alarm = Alarm(label: "Active", hour: 7, minute: 0, repeatDays: [])
        store.add(alarm)

        store.expireOneTimeAlarms(reference: expiryNow, excludingIDs: [alarm.id])

        guard let kept = store.alarms.first(where: { $0.id == alarm.id }) else {
            return XCTFail("Expected alarm to exist")
        }
        XCTAssertFalse(kept.hasFired)
        XCTAssertTrue(kept.isEnabled)
    }

    func testAlarmForSchedulingSkipsExpiredOneTimeAlarm() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let store = AlarmStore(nowProvider: { now })
        let alarm = Alarm(label: "Past", hour: 7, minute: 30, repeatDays: [])
        store.add(alarm)

        XCTAssertNil(store.alarmForScheduling(id: alarm.id))
    }

    func testAlarmForSchedulingReturnsNormalizedPersistedAlarm() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 6, minute: 0))!
        let store = AlarmStore(nowProvider: { now })
        let alarm = Alarm(
            label: "  Study  ",
            hour: 8,
            minute: 15,
            repeatDays: [2],
            problemCount: 99
        )
        store.add(alarm)

        let persisted = store.alarmForScheduling(id: alarm.id)

        XCTAssertEqual(persisted?.label, "Study")
        XCTAssertEqual(persisted?.problemCount, 10)
        XCTAssertEqual(persisted?.repeatDays, [2])
        XCTAssertTrue(persisted?.isEnabled == true)
    }

    func testAlarmForSchedulingSkipsDisabledAlarm() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 6, minute: 0))!
        let store = AlarmStore(nowProvider: { now })
        let alarm = Alarm(label: "Off", hour: 8, minute: 15, isEnabled: false)
        store.add(alarm)

        XCTAssertNil(store.alarmForScheduling(id: alarm.id))
    }

    func testAlarmForSchedulingSkipsStaleOneTimeAlarmEvenBeforeExpirationPass() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let store = AlarmStore(nowProvider: { now })
        let alarm = Alarm(label: "Stale", hour: 7, minute: 30, repeatDays: [])
        store.alarms = [alarm]

        XCTAssertNil(store.alarmForScheduling(id: alarm.id))
    }
}

final class AlarmSchedulerPolicyTests: XCTestCase {
    func testPermissionStateMapping() {
        XCTAssertEqual(AlarmScheduler.permissionState(for: .notDetermined), .unknown)
        XCTAssertEqual(AlarmScheduler.permissionState(for: .denied), .denied)
        XCTAssertEqual(AlarmScheduler.permissionState(for: .authorized), .granted)
    }

    func testKeepRingingDisablesAutoSnoozeScheduling() {
        XCTAssertFalse(AlarmScheduler.shouldScheduleSnooze(keepRinging: true))
        XCTAssertTrue(AlarmScheduler.shouldScheduleSnooze(keepRinging: false))
    }
}
