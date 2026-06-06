import XCTest
@testable import AlarmedByMath

/// Tests for the math-gate state store and the alarm fire-date helper that
/// drive the locked-screen alarm behaviour.
final class AlarmGateTests: XCTestCase {

    private var ids: [String] = []
    private let alarmsKey = "saved_alarms"

    private func freshID() -> String {
        let id = UUID().uuidString
        ids.append(id)
        return id
    }

    override func tearDown() {
        // Clean up any keys we touched so we don't leak into other tests.
        for id in ids { AlarmGate.forget(id) }
        AlarmGate.pendingMathAlarmID = nil
        UserDefaults.standard.removeObject(forKey: alarmsKey)
        SettingsStore.shared.setWhizPlanFromEntitlement(.free)
        PremiumPlugin.resetForTesting()
        ids.removeAll()
        super.tearDown()
    }

    func testWhizProductIdentifierMatchesBundleNaming() {
        XCTAssertEqual(SettingsStore.whizProductID, "com.alarmedbymath.app.whiz")
    }

    func testSolvedFlagDefaultsFalse() {
        let id = freshID()
        XCTAssertFalse(AlarmGate.isSolved(id))
    }

    func testMarkSolvedAndReset() {
        let id = freshID()
        AlarmGate.markSolved(id)
        XCTAssertTrue(AlarmGate.isSolved(id))
        AlarmGate.reset(id)
        XCTAssertFalse(AlarmGate.isSolved(id))
        XCTAssertEqual(AlarmGate.reringCount(id), 0)
    }

    func testReringCounterIncrements() {
        let id = freshID()
        XCTAssertEqual(AlarmGate.incrementRerings(id), 1)
        XCTAssertEqual(AlarmGate.incrementRerings(id), 2)
        XCTAssertEqual(AlarmGate.reringCount(id), 2)
        AlarmGate.reset(id)
        XCTAssertEqual(AlarmGate.reringCount(id), 0)
    }

    func testReringIDTracking() {
        let id = freshID()
        XCTAssertTrue(AlarmGate.reringIDs(id).isEmpty)
        AlarmGate.addReringID(id, "ring-1")
        AlarmGate.addReringID(id, "ring-2")
        XCTAssertEqual(AlarmGate.reringIDs(id), ["ring-1", "ring-2"])
        AlarmGate.clearReringIDs(id)
        XCTAssertTrue(AlarmGate.reringIDs(id).isEmpty)
    }

    func testReringIDReverseLookup() {
        let id = freshID()
        AlarmGate.addReringID(id, "ring-A")
        AlarmGate.addReringID(id, "ring-B")
        // A re-ring id resolves back to the alarm that spawned it.
        XCTAssertEqual(AlarmGate.originalID(forRingingID: "ring-A"), id)
        XCTAssertEqual(AlarmGate.originalID(forRingingID: "ring-B"), id)
        // A primary id (no mapping) resolves to itself.
        XCTAssertEqual(AlarmGate.originalID(forRingingID: id), id)
        // Clearing removes the reverse mapping too.
        AlarmGate.clearReringIDs(id)
        XCTAssertEqual(AlarmGate.originalID(forRingingID: "ring-A"), "ring-A")
    }

    func testPendingMathHandoff() {
        let id = freshID()
        AlarmGate.pendingMathAlarmID = id
        XCTAssertEqual(AlarmGate.pendingMathAlarmID, id)
        AlarmGate.pendingMathAlarmID = nil
        XCTAssertNil(AlarmGate.pendingMathAlarmID)
    }

    func testLabelRoundTrip() {
        let id = freshID()
        XCTAssertEqual(AlarmGate.label(id), "Alarm")  // default
        AlarmGate.setLabel(id, "Wake up")
        XCTAssertEqual(AlarmGate.label(id), "Wake up")
    }

    func testAlarmStoreDowngradesWhizDifficultyWhenLocked() {
        SettingsStore.shared.setWhizPlanFromEntitlement(.free)
        let store = AlarmStore()
        store.add(Alarm(label: "Study", difficulty: .whiz))

        XCTAssertEqual(store.alarms.last?.difficulty, .expert)
    }

    func testAlarmStoreDowngradesWhizWhenPremiumUnavailable() {
        // Even with a Premium entitlement, a free build (no premium add-on
        // registered) must downgrade Whiz alarms so the open-source app never
        // surfaces paid content.
        PremiumPlugin.resetForTesting()
        SettingsStore.shared.setWhizPlanFromEntitlement(.whiz)
        let store = AlarmStore()
        store.add(Alarm(label: "Olympiad", difficulty: .whiz))

        XCTAssertEqual(store.alarms.last?.difficulty, .expert)
    }

    func testCustomSongsResolvedOnlyWhenPremium() {
        let scheduler = AlarmScheduler()

        SettingsStore.shared.setWhizPlanFromEntitlement(.free)
        XCTAssertFalse(scheduler.supportsCustomSongs)
        XCTAssertNil(scheduler.resolvedSongID("12345"),
                     "Free users must not get a custom song persisted")

        SettingsStore.shared.setWhizPlanFromEntitlement(.whiz)
        XCTAssertTrue(scheduler.supportsCustomSongs)
        XCTAssertEqual(scheduler.resolvedSongID("12345"), "12345",
                       "Premium users keep their chosen song")
        XCTAssertNil(scheduler.resolvedSongID(nil),
                     "A nil selection stays nil for premium users")
    }
}

final class AlarmFireDateTests: XCTestCase {

    func testNextFireDateIsInFutureForOneTimeAlarm() {
        let cal = Calendar.current
        // Pin "now" to mid-morning so target ±1h stays within the same day,
        // making the assertion deterministic at any real wall-clock time.
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9, minute: 0))!
        let future = cal.date(byAdding: .hour, value: 1, to: now) ?? now
        let comps = cal.dateComponents([.hour, .minute], from: future)
        let alarm = Alarm(hour: comps.hour ?? 8, minute: comps.minute ?? 0, repeatDays: [])
        let next = AlarmScheduler.nextFireDate(for: alarm, now: now)
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next!, now)
        let nextComps = cal.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(nextComps.hour, alarm.hour)
        XCTAssertEqual(nextComps.minute, alarm.minute)
    }

    func testNextFireDateMatchesARepeatWeekday() {
        let alarm = Alarm(hour: 7, minute: 0, repeatDays: [2, 4])  // Mon, Wed
        let next = AlarmScheduler.nextFireDate(for: alarm)
        XCTAssertNotNil(next)
        let weekday = Calendar.current.component(.weekday, from: next!)
        XCTAssertTrue([2, 4].contains(weekday))
    }
}

final class PremiumLinksTests: XCTestCase {

    // App Review requires functional Terms of Use and Privacy Policy links
    // wherever an in-app purchase is offered. Guard against shipping a
    // malformed or non-HTTPS URL by accident.
    func testLegalLinksAreSecureURLs() {
        for url in [PremiumLinks.termsOfUse, PremiumLinks.privacyPolicy] {
            XCTAssertEqual(url.scheme, "https",
                           "Legal link must be served over HTTPS: \(url)")
            XCTAssertNotNil(url.host,
                            "Legal link must have a host: \(url)")
        }
    }
}

final class WidgetSharedStoreTests: XCTestCase {

    // The snapshot crosses the app/extension boundary as JSON, so encoding must
    // round-trip every field the widget renders.
    func testSnapshotCodableRoundTrip() throws {
        let original = WidgetSharedStore.Snapshot(
            isPremiumUnlocked: true,
            nextAlarmDate: Date(timeIntervalSince1970: 1_700_000_000),
            nextAlarmLabel: "Morning run",
            currentStreak: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetSharedStore.Snapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSaveThenLoadReturnsSameSnapshot() {
        let saved = WidgetSharedStore.Snapshot(
            isPremiumUnlocked: true,
            nextAlarmDate: Date(timeIntervalSince1970: 1_700_000_500),
            nextAlarmLabel: "Standup",
            currentStreak: 3
        )
        defer { WidgetSharedStore.save(.placeholder) }

        WidgetSharedStore.save(saved)
        XCTAssertEqual(WidgetSharedStore.load(), saved)
    }

    func testPlaceholderIsLockedWithNoAlarm() {
        let placeholder = WidgetSharedStore.Snapshot.placeholder
        XCTAssertFalse(placeholder.isPremiumUnlocked,
                       "Locked is the safe default so a free user never sees paid content")
        XCTAssertNil(placeholder.nextAlarmDate)
        XCTAssertEqual(placeholder.currentStreak, 0)
    }

    func testPaywallDeepLinkURLIsStable() {
        // The app's .onOpenURL handler matches on this exact URL.
        XCTAssertEqual(WidgetSharedStore.paywallURL.absoluteString, "alarmedbymath://paywall")
    }
}
