import XCTest
import AVFoundation
import SwiftUI
@testable import AlarmedByMath

private func testWeekdayCalendar(locale: String = "en_US", firstWeekday: Int = 1) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: locale)
    calendar.firstWeekday = firstWeekday
    return calendar
}

final class AlarmTests: XCTestCase {

    private func twelveHourTime(_ alarm: Alarm) -> String {
        alarm.formattedTime(locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

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
        XCTAssertEqual(twelveHourTime(Alarm(hour: 8, minute: 30)), "8:30 AM")
    }

    func testTimeStringAfternoon() {
        XCTAssertEqual(twelveHourTime(Alarm(hour: 14, minute: 5)), "2:05 PM")
    }

    func testTimeStringMidnight() {
        XCTAssertEqual(twelveHourTime(Alarm(hour: 0, minute: 0)), "12:00 AM")
    }

    func testTimeStringNoon() {
        XCTAssertEqual(twelveHourTime(Alarm(hour: 12, minute: 0)), "12:00 PM")
    }

    func testTimeStringLeadingZeroMinute() {
        XCTAssertEqual(twelveHourTime(Alarm(hour: 9, minute: 5)), "9:05 AM")
    }

    func testTimeUsesTwentyFourHourLocale() {
        let locale = Locale(identifier: "en_GB")
        XCTAssertEqual(Alarm(hour: 14, minute: 5).formattedTime(locale: locale), "14:05")
        XCTAssertEqual(Alarm(hour: 0, minute: 0).formattedTime(locale: locale), "00:00")
    }

    func testTimeStringUsesCurrentLocale() {
        XCTAssertEqual(Alarm(hour: 14, minute: 5).timeString,
                       Alarm(hour: 14, minute: 5).formattedTime(locale: .autoupdatingCurrent))
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
        XCTAssertEqual(alarm.formattedRepeatLabel(calendar: testWeekdayCalendar()), "Mon, Tue, Wed, Thu, Fri")
    }

    func testRepeatLabelWeekend() {
        let alarm = Alarm(repeatDays: [1, 7])
        XCTAssertEqual(alarm.formattedRepeatLabel(calendar: testWeekdayCalendar()), "Sun, Sat")
    }

    func testWeekdaysFollowConfiguredFirstDay() {
        let calendar = testWeekdayCalendar(firstWeekday: 2)
        XCTAssertEqual(Alarm.orderedWeekdays(calendar: calendar), [2, 3, 4, 5, 6, 7, 1])
        XCTAssertEqual(Alarm(repeatDays: [1, 7]).formattedRepeatLabel(calendar: calendar), "Sat, Sun")
    }

    func testWeekdayLabelsUseCalendarLocale() {
        let calendar = testWeekdayCalendar(locale: "fr_FR", firstWeekday: 2)
        let alarm = Alarm(repeatDays: [1, 2])
        XCTAssertEqual(alarm.formattedRepeatLabel(calendar: calendar), "lun., dim.")
        XCTAssertEqual(Alarm.orderedWeekdays(calendar: calendar).count, 7)
        XCTAssertEqual(Set(Alarm.orderedWeekdays(calendar: calendar)), Set(1...7))
    }

    // MARK: - detailLabel

    func testDetailLabelWithoutName() {
        let alarm = Alarm(repeatDays: [2, 4, 6])
        XCTAssertEqual(alarm.detailLabel, alarm.repeatLabel)
    }

    func testDetailLabelWithNameIncludesComma() {
        let alarm = Alarm(label: "Gym", repeatDays: [2, 4, 6])
        XCTAssertEqual(alarm.detailLabel, "Gym, \(alarm.repeatLabel)")
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

    func testDuplicateDraftPreservesSettingsWithoutArmingOrReusingIdentity() {
        let original = Alarm(
            label: "Study", hour: 7, minute: 20, repeatDays: [2, 4],
            difficulty: .expert, problemCount: 3, songPersistentID: "123",
            songTitle: "Morning", volume: 0.6, snoozeDuration: 8,
            keepRinging: true, hasFired: true
        )
        let draft = original.duplicateDraft()

        XCTAssertNotEqual(draft.id, original.id)
        XCTAssertNotEqual(draft.id, original.duplicateDraft().id)
        XCTAssertFalse(draft.isEnabled)
        XCTAssertFalse(draft.hasFired)
        XCTAssertTrue(original.isEnabled)
        XCTAssertTrue(original.hasFired)
        XCTAssertEqual(draft.label, original.label)
        XCTAssertEqual(draft.hour, original.hour)
        XCTAssertEqual(draft.minute, original.minute)
        XCTAssertEqual(draft.repeatDays, original.repeatDays)
        XCTAssertEqual(draft.difficulty, original.difficulty)
        XCTAssertEqual(draft.problemCount, original.problemCount)
        XCTAssertEqual(draft.songPersistentID, original.songPersistentID)
        XCTAssertEqual(draft.songTitle, original.songTitle)
        XCTAssertEqual(draft.volume, original.volume)
        XCTAssertEqual(draft.snoozeDuration, original.snoozeDuration)
        XCTAssertEqual(draft.keepRinging, original.keepRinging)
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
        XCTAssertEqual(queue.alarmIDs, ["a", "b"])
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

    func testTypographyUsesOneDesignAndThreeSemanticSizes() {
        let settings = SettingsStore.shared
        let previousTheme = settings.activeTheme
        let previousSavedTheme = UserDefaults.standard.object(forKey: "settings_theme")
        defer {
            settings.activeTheme = previousTheme
            if let previousSavedTheme {
                UserDefaults.standard.set(previousSavedTheme, forKey: "settings_theme")
            } else {
                UserDefaults.standard.removeObject(forKey: "settings_theme")
            }
        }
        for theme in AppTheme.allCases {
            settings.activeTheme = theme
            let design = theme.colors.fontDesign
            XCTAssertEqual(AppTypography.body, Font.system(.body, design: design))
            XCTAssertEqual(AppTypography.emphasis, AppTypography.body.weight(.semibold))
            XCTAssertEqual(AppTypography.title, Font.system(.title2, design: design).weight(.semibold))
            XCTAssertEqual(AppTypography.display, Font.system(.largeTitle, design: design).weight(.semibold))
        }
    }

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

    func testRefinedChalkboardTextAndFilledButtonsMeetAA() {
        let colors = AppTheme.chalk.colors
        for background in [colors.boardSwatch, colors.boardDarkSwatch] {
            for foreground in [colors.chalkSwatch, colors.chalkFadedSwatch,
                               colors.chalkYellowSwatch, colors.chalkRedSwatch,
                               colors.chalkBlueSwatch] {
                XCTAssertGreaterThanOrEqual(background.contrastRatio(with: foreground), 4.5)
            }
        }
        XCTAssertGreaterThanOrEqual(colors.chalkYellowSwatch.contrastRatio(with: colors.boardDarkSwatch), 4.5)
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

        XCTAssertEqual(store.alarms.map { $0.hour * 60 + $0.minute }, [375, 480, 570])
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

        XCTAssertEqual(store.alarms.map { $0.hour * 60 + $0.minute }, [345, 360])
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
        XCTAssertEqual(alarm.formattedRepeatLabel(calendar: testWeekdayCalendar()), "Sun, Wed")
    }
}

final class AlarmOneTimeFireDateTests: XCTestCase {
    func testOneTimePastAlarmDoesNotRescheduleTomorrow() {
        let cal = Calendar.current
        // Pin "now" so "one hour ago" stays within the same day; otherwise this
        // assertion flakes between 00:00–00:59 when now−1h lands on yesterday.
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let oneHourAgo = cal.date(byAdding: .hour, value: -1, to: now) ?? now
        let comps = cal.dateComponents([.hour, .minute], from: oneHourAgo)
        let alarm = Alarm(hour: comps.hour ?? 0, minute: comps.minute ?? 0, repeatDays: [])

        XCTAssertNil(AlarmScheduler.nextFireDate(for: alarm, now: now))
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

    func testNewOneTimePastTimeSchedulesTomorrow() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let store = AlarmStore(nowProvider: { now })
        store.add(Alarm(label: "Past", hour: 7, minute: 30, repeatDays: []))

        XCTAssertEqual(store.alarms.count, 1)
        XCTAssertFalse(store.alarms[0].hasFired)
        XCTAssertTrue(store.alarms[0].isEnabled)
        XCTAssertEqual(store.alarms[0].oneTimeDay, AlarmDay(date: cal.date(byAdding: .day, value: 1, to: now)!, calendar: cal))
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
        let alarm = Alarm(label: "Past", hour: 7, minute: 30, repeatDays: [],
                          oneTimeDay: AlarmDay(date: now, calendar: .current))
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
    func testPreviewSnoozeDoesNotScheduleOrRecordARealAlarm() {
        let scheduler = AlarmScheduler()
        let id = UUID().uuidString
        let snoozesBefore = StatsStore.shared.stats.totalSnoozesTaken
        defer { AlarmGate.forget(id) }
        scheduler.startRinging(alarmID: id, volume: 0, preview: true)
        XCTAssertTrue(scheduler.isPreview)

        scheduler.snooze()

        XCTAssertEqual(StatsStore.shared.stats.totalSnoozesTaken, snoozesBefore)
        XCTAssertTrue(scheduler.schedulingFailures.isEmpty)
        XCTAssertTrue(AlarmGate.reringIDs(id).isEmpty)
        scheduler.dismiss()
        XCTAssertFalse(scheduler.isRinging)
        XCTAssertFalse(AlarmGate.isSolved(id))
    }

    func testPermissionStateMapping() {
        XCTAssertEqual(AlarmScheduler.permissionState(for: .notDetermined), .unknown)
        XCTAssertEqual(AlarmScheduler.permissionState(for: .denied), .denied)
        XCTAssertEqual(AlarmScheduler.permissionState(for: .authorized), .granted)
        XCTAssertEqual(AlarmScheduler.permissionState(for: .provisional), .unknown)
    }

    func testKeepRingingDisablesAutoSnoozeScheduling() {
        XCTAssertFalse(AlarmScheduler.shouldScheduleSnooze(keepRinging: true))
        XCTAssertTrue(AlarmScheduler.shouldScheduleSnooze(keepRinging: false))
    }

    func testAlarmKitReadinessDoesNotDependOnNotificationPermissionOrSound() {
        XCTAssertNil(AlarmScheduler.readinessWarning(
            usesAlarmKit: true, alarmPermission: .granted,
            notificationPermission: .denied, notificationSoundsEnabled: false
        ))
    }

    func testNotificationPermissionDoesNotMaskDeniedAlarmKitAccess() {
        let warning = AlarmScheduler.readinessWarning(
            usesAlarmKit: true, alarmPermission: .denied,
            notificationPermission: .granted, notificationSoundsEnabled: true
        )
        XCTAssertTrue(warning?.contains("Alarm access is off") == true)
    }

    func testUnknownAlarmKitPermissionRequiresSetup() {
        let warning = AlarmScheduler.readinessWarning(
            usesAlarmKit: true, alarmPermission: .unknown,
            notificationPermission: .granted, notificationSoundsEnabled: true
        )
        XCTAssertTrue(warning?.contains("Allow alarm access") == true)
    }

    func testFallbackReadinessRequiresNotificationSounds() {
        let warning = AlarmScheduler.readinessWarning(
            usesAlarmKit: false, alarmPermission: .granted,
            notificationPermission: .granted, notificationSoundsEnabled: false
        )
        XCTAssertTrue(warning?.contains("Notification sounds are off") == true)
    }

    func testFallbackReadinessUsesNotificationPermission() {
        XCTAssertNotNil(AlarmScheduler.readinessWarning(
            usesAlarmKit: false, alarmPermission: .granted,
            notificationPermission: .denied, notificationSoundsEnabled: true
        ))
        XCTAssertNil(AlarmScheduler.readinessWarning(
            usesAlarmKit: false, alarmPermission: .denied,
            notificationPermission: .granted, notificationSoundsEnabled: true
        ))
    }
}

final class AlarmSoundTests: XCTestCase {
    func testV2ContainsExactlyTheApprovedSounds() {
        XCTAssertEqual(
            AlarmSound.allCases.map(\.label),
            ["Chime", "Daybreak", "Glasshouse", "Clockwork", "Bell", "Buzz", "Roll Call", "Ratchet"]
        )
        XCTAssertEqual(Set(AlarmSound.allCases.map(\.fileName)).count, 8)
        XCTAssertEqual(AlarmSound.chime.fileName, "chime.caf")
        XCTAssertEqual(AlarmSound.bell.fileName, "bell_v2.caf")
        XCTAssertEqual(AlarmSound.buzzOnly.fileName, "buzz_v2.caf")
        XCTAssertEqual(AlarmSound.glasshouse.fileName, "glasshouse.caf")
        XCTAssertEqual(AlarmSound.ratchet.fileName, "ratchet.caf")
    }

    func testLegacySelectionsMigrateWithoutLosingTheirIdentity() {
        XCTAssertEqual(AlarmSound.fromStoredValue("classic"), .rollCall)
        XCTAssertEqual(AlarmSound.fromStoredValue("bell"), .bell)
        XCTAssertEqual(AlarmSound.fromStoredValue("buzzOnly"), .buzzOnly)
        XCTAssertEqual(AlarmSound.fromStoredValue("chime"), .chime)
        XCTAssertNil(AlarmSound.fromStoredValue("missing-sound"))
        for sound in AlarmSound.allCases {
            XCTAssertEqual(AlarmSound.fromStoredValue(sound.rawValue), sound)
        }
    }

    func testSettingsPersistClassicMigrationAndNewSelection() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "settings_sound")
        defer {
            if let original {
                defaults.set(original, forKey: "settings_sound")
            } else {
                defaults.removeObject(forKey: "settings_sound")
            }
        }
        defaults.set("classic", forKey: "settings_sound")
        let settings = SettingsStore(storeKitEnabled: false)
        XCTAssertEqual(settings.alarmSound, .rollCall)
        XCTAssertEqual(defaults.string(forKey: "settings_sound"), "rollCall")

        settings.alarmSound = .glasshouse
        XCTAssertEqual(SettingsStore(storeKitEnabled: false).alarmSound, .glasshouse)

        defaults.removeObject(forKey: "settings_sound")
        XCTAssertEqual(SettingsStore(storeKitEnabled: false).alarmSound, .chime)
    }

    func testAllBundledSoundsArePlayableNotificationLengthPCM() throws {
        let bundle = Bundle(for: AlarmScheduler.self)
        for sound in AlarmSound.allCases {
            let url = try XCTUnwrap(bundle.url(
                forResource: sound.resource.name, withExtension: sound.resource.ext
            ), "Missing bundled sound: \(sound.fileName)")
            let file = try AVAudioFile(forReading: url)
            XCTAssertEqual(file.fileFormat.channelCount, 1)
            XCTAssertEqual(file.fileFormat.sampleRate, 44_100)
            XCTAssertEqual(file.fileFormat.commonFormat, .pcmFormatInt16)
            XCTAssertGreaterThan(file.length, 0)
            XCTAssertLessThan(file.length, AVAudioFramePosition(30 * 44_100))
            XCTAssertEqual(file.length, AVAudioFramePosition((sound == .chime ? 20 : 24) * 44_100))

            let buffer = try XCTUnwrap(AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)
            ))
            try file.read(into: buffer)
            let channels = try XCTUnwrap(buffer.floatChannelData)
            let samples = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
            XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
            let peak = samples.reduce(Float.zero) { max($0, abs($1)) }
            XCTAssertGreaterThan(peak, 0)
            if sound != .chime {
                XCTAssertLessThanOrEqual(peak, 0.355)
                XCTAssertEqual(samples.first, 0)
                XCTAssertEqual(samples.last, 0)
            }
        }
    }
}
