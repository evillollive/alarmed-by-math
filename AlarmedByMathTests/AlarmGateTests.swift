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

    func testAlarmStoreKeepsWhizDifficultyWhenUnlocked() {
        SettingsStore.shared.setWhizPlanFromEntitlement(.whiz)
        let store = AlarmStore()
        store.add(Alarm(label: "Olympiad", difficulty: .whiz))

        XCTAssertEqual(store.alarms.last?.difficulty, .whiz)
    }
}

final class AlarmFireDateTests: XCTestCase {

    func testNextFireDateIsInFutureForOneTimeAlarm() {
        let alarm = Alarm(hour: 6, minute: 30, repeatDays: [])
        let next = AlarmScheduler.nextFireDate(for: alarm)
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next!, Date())
        let comps = Calendar.current.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 6)
        XCTAssertEqual(comps.minute, 30)
    }

    func testNextFireDateMatchesARepeatWeekday() {
        let alarm = Alarm(hour: 7, minute: 0, repeatDays: [2, 4])  // Mon, Wed
        let next = AlarmScheduler.nextFireDate(for: alarm)
        XCTAssertNotNil(next)
        let weekday = Calendar.current.component(.weekday, from: next!)
        XCTAssertTrue([2, 4].contains(weekday))
    }
}
