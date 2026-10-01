import XCTest
import AVFoundation
@testable import AlarmedByMath

private enum AudioTestError: Error {
    case refused
}

private final class ControlledAudioSession: AudioSessionControlling {
    var activations: [(Result<Void, Error>) -> Void] = []
    var deactivations: [(Result<Void, Error>) -> Void] = []

    func activate(preparation: @escaping () throws -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        activations.append { result in
            guard case .success = result else { completion(result); return }
            do {
                try preparation()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deactivate(completion: @escaping (Result<Void, Error>) -> Void) {
        deactivations.append(completion)
    }
}

private final class RecordingAudioPlayer: AlarmAudioPlaying {
    var duration: TimeInterval = 24
    var numberOfLoops = 0
    var volume: Float = 0
    var canPlay = true
    var canPrepare = true
    private(set) var prepareCount = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0

    func prepareToPlay() -> Bool {
        prepareCount += 1
        return canPrepare
    }

    func play() -> Bool {
        playCount += 1
        return canPlay
    }

    func stop() {
        stopCount += 1
    }
}

final class AudioLifecycleTests: XCTestCase {
    private let songURL = URL(fileURLWithPath: "/test-only-song.caf")

    private func scheduler(
        session: ControlledAudioSession,
        players: [RecordingAudioPlayer]
    ) -> AlarmScheduler {
        var index = 0
        return AlarmScheduler(audioSession: session) { _ in
            guard index < players.count else {
                XCTFail("Unexpected player creation")
                throw AudioTestError.refused
            }
            defer { index += 1 }
            return players[index]
        }
    }

    func testStoppedPreviewCannotStartAfterLateActivation() {
        let session = ControlledAudioSession()
        let player = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [player])
        let selected = SettingsStore.shared.alarmSound

        scheduler.previewSound(.daybreak)
        XCTAssertEqual(scheduler.previewingSound, .daybreak)
        XCTAssertEqual(player.playCount, 0)
        scheduler.stopSoundPreview()
        session.activations[0](.success(()))

        XCTAssertNil(scheduler.previewingSound)
        XCTAssertEqual(player.playCount, 0)
        XCTAssertEqual(session.deactivations.count, 1)
        XCTAssertEqual(SettingsStore.shared.alarmSound, selected)
    }

    func testReplacingPreviewIgnoresAnOlderCompletion() {
        let session = ControlledAudioSession()
        let first = RecordingAudioPlayer()
        let second = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [first, second])
        defer { scheduler.stopSoundPreview() }
        scheduler.previewSound(.daybreak)
        scheduler.previewSound(.glasshouse)
        session.activations[1](.success(()))
        session.activations[0](.success(()))

        XCTAssertEqual(first.playCount, 0)
        XCTAssertEqual(second.playCount, 1)
        XCTAssertEqual(second.numberOfLoops, 0)
        XCTAssertEqual(scheduler.previewingSound, .glasshouse)
    }

    func testPreviewActivationFailureIsVisibleAndReleasesSession() {
        let session = ControlledAudioSession()
        let player = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [player])
        scheduler.previewSound(.chime)
        session.activations[0](.failure(AudioTestError.refused))

        XCTAssertEqual(player.playCount, 0)
        XCTAssertNil(scheduler.previewingSound)
        XCTAssertNotNil(scheduler.previewErrorMessage)
        XCTAssertEqual(session.deactivations.count, 1)
    }

    func testPreviewPlaybackFailureIsNotReportedAsPlaying() {
        let session = ControlledAudioSession()
        let player = RecordingAudioPlayer()
        player.canPlay = false
        let scheduler = scheduler(session: session, players: [player])
        scheduler.previewSound(.bell)
        session.activations[0](.success(()))

        XCTAssertNil(scheduler.previewingSound)
        XCTAssertTrue(scheduler.previewErrorMessage?.contains("could not start") == true)
        XCTAssertEqual(session.deactivations.count, 1)
    }

    func testPreparationFailureStopsThePlayerWithoutPlayback() {
        let session = ControlledAudioSession()
        let player = RecordingAudioPlayer()
        player.canPrepare = false
        let scheduler = scheduler(session: session, players: [player])
        scheduler.previewSound(.daybreak)
        session.activations[0](.success(()))

        XCTAssertEqual(player.prepareCount, 1)
        XCTAssertEqual(player.playCount, 0)
        XCTAssertEqual(player.stopCount, 1)
        XCTAssertNil(scheduler.previewingSound)
        XCTAssertNotNil(scheduler.previewErrorMessage)
        XCTAssertEqual(session.deactivations.count, 1)
    }

    func testCancelledPreparedPlayerStopsBeforeSessionDeactivation() {
        let activated = expectation(description: "activation started")
        let deactivated = expectation(description: "prepared player released")
        let player = RecordingAudioPlayer()
        var completeActivation: ((Result<Void, Error>) -> Void)?
        let session = AudioSessionController { active, completion in
            if active {
                DispatchQueue.main.async {
                    completeActivation = completion
                    activated.fulfill()
                }
            } else {
                XCTAssertEqual(player.stopCount, 1)
                XCTAssertEqual(player.playCount, 0)
                completion(.success(()))
                deactivated.fulfill()
            }
        }
        let scheduler = AlarmScheduler(audioSession: session, makePlayer: { _ in player })
        scheduler.previewSound(.daybreak)
        wait(for: [activated], timeout: 2)
        scheduler.stopSoundPreview()
        completeActivation?(.success(()))
        wait(for: [deactivated], timeout: 2)
        XCTAssertNil(scheduler.previewingSound)
    }

    func testWakeAudioTakesPriorityOverPendingPreview() {
        let session = ControlledAudioSession()
        let preview = RecordingAudioPlayer()
        let wake = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [preview, wake])
        defer { scheduler.dismiss() }

        scheduler.previewSound(.daybreak)
        scheduler.startRinging(alarmID: "wake-test", volume: 0.4, preview: true)
        session.activations[0](.success(()))
        session.activations[1](.success(()))
        let releases = session.deactivations.count
        scheduler.stopSoundPreview()

        XCTAssertNil(scheduler.previewingSound)
        XCTAssertEqual(preview.playCount, 0)
        XCTAssertEqual(wake.playCount, 1)
        XCTAssertEqual(wake.numberOfLoops, -1)
        XCTAssertEqual(wake.volume, 0.4)
        XCTAssertEqual(wake.stopCount, 0)
        XCTAssertEqual(session.deactivations.count, releases)
    }

    func testSnoozingPendingWakeAudioPreventsLatePlayback() {
        let session = ControlledAudioSession()
        let wake = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [wake])
        defer { scheduler.dismiss() }
        scheduler.startRinging(alarmID: "wake-test", preview: true)
        scheduler.snooze()
        session.activations[0](.success(()))

        XCTAssertEqual(wake.playCount, 0)
        XCTAssertTrue(scheduler.isRinging)
        XCTAssertEqual(session.deactivations.count, 1)
    }

    @available(iOS 26.1, *)
    func testSystemAlarmHandoffCancelsAPendingSoundPreview() {
        let session = ControlledAudioSession()
        let preview = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [preview])
        let id = UUID().uuidString
        let previousPending = AlarmGate.pendingMathAlarmID
        defer {
            scheduler.dismiss()
            AlarmGate.forget(id)
            AlarmGate.pendingMathAlarmID = previousPending
        }
        scheduler.previewSound(.daybreak)
        AlarmGate.pendingMathAlarmID = id
        XCTAssertTrue(scheduler.presentMathIfPending())
        session.activations[0](.success(()))

        XCTAssertNil(scheduler.previewingSound)
        XCTAssertEqual(preview.playCount, 0)
        XCTAssertEqual(scheduler.activeAlarmID, id)
        XCTAssertTrue(scheduler.isRinging)
    }

    func testStaleDeactivationFailureDoesNotOverwriteANewPreview() {
        let session = ControlledAudioSession()
        let scheduler = scheduler(session: session, players: [RecordingAudioPlayer(), RecordingAudioPlayer()])
        defer { scheduler.stopSoundPreview() }
        scheduler.previewSound(.daybreak)
        session.activations[0](.success(()))
        scheduler.stopSoundPreview()
        scheduler.previewSound(.glasshouse)
        session.deactivations[0](.failure(AudioTestError.refused))
        session.activations[1](.success(()))

        XCTAssertNil(scheduler.previewErrorMessage)
        XCTAssertEqual(scheduler.previewingSound, .glasshouse)
    }

    func testSoundtrackReplacesWakeAudioOnlyAfterItStarts() {
        let settings = SettingsStore.shared
        let previous = settings.whizPlan
        settings.setWhizPlanFromEntitlement(.whiz)
        defer { settings.setWhizPlanFromEntitlement(previous) }
        let session = ControlledAudioSession()
        let wake = RecordingAudioPlayer()
        let song = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [wake, song])
        defer { scheduler.dismiss() }
        scheduler.startRinging(alarmID: "song-test", preview: true)
        session.activations[0](.success(()))

        scheduler.startSolveSoundtrack(assetURL: songURL, alarmID: "song-test", volume: 0.6)
        XCTAssertEqual(wake.stopCount, 0)
        XCTAssertEqual(song.playCount, 0)
        session.activations[1](.success(()))
        XCTAssertEqual(song.playCount, 1)
        XCTAssertEqual(song.numberOfLoops, -1)
        XCTAssertEqual(wake.stopCount, 1)
        XCTAssertEqual(session.deactivations.count, 0)

        scheduler.stopSolveSoundtrack(for: "previous-alarm")
        XCTAssertEqual(song.stopCount, 0)
        scheduler.stopSolveSoundtrack(for: "song-test")
        XCTAssertEqual(song.stopCount, 1)
        XCTAssertEqual(session.deactivations.count, 1)
    }

    func testSoundtrackFailureLeavesWakeAudioRunning() {
        let settings = SettingsStore.shared
        let previous = settings.whizPlan
        settings.setWhizPlanFromEntitlement(.whiz)
        defer { settings.setWhizPlanFromEntitlement(previous) }
        let session = ControlledAudioSession()
        let wake = RecordingAudioPlayer()
        let song = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [wake, song])
        defer { scheduler.dismiss() }
        scheduler.startRinging(alarmID: "song-test", preview: true)
        session.activations[0](.success(()))
        scheduler.startSolveSoundtrack(assetURL: songURL, alarmID: "song-test", volume: 1)
        session.activations[1](.failure(AudioTestError.refused))

        XCTAssertEqual(wake.stopCount, 0)
        XCTAssertEqual(song.playCount, 0)
        XCTAssertEqual(session.deactivations.count, 0)
        XCTAssertNotNil(scheduler.schedulingFailures["song-test"])
    }

    func testSnoozingWakeAudioPreservesPendingSolveSoundtrack() {
        let settings = SettingsStore.shared
        let previous = settings.whizPlan
        settings.setWhizPlanFromEntitlement(.whiz)
        defer { settings.setWhizPlanFromEntitlement(previous) }
        let session = ControlledAudioSession()
        let wake = RecordingAudioPlayer()
        let song = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [wake, song])
        defer { scheduler.dismiss() }
        scheduler.startRinging(alarmID: "song-test", preview: true)
        session.activations[0](.success(()))
        scheduler.startSolveSoundtrack(assetURL: songURL, alarmID: "song-test", volume: 1)
        scheduler.snooze()
        session.activations[1](.success(()))

        XCTAssertEqual(song.playCount, 1)
        XCTAssertEqual(wake.stopCount, 1)
        XCTAssertEqual(session.deactivations.count, 0)
    }

    func testCancelledSoundtrackCannotStartAfterDismissal() {
        let settings = SettingsStore.shared
        let previous = settings.whizPlan
        settings.setWhizPlanFromEntitlement(.whiz)
        defer { settings.setWhizPlanFromEntitlement(previous) }
        let session = ControlledAudioSession()
        let wake = RecordingAudioPlayer()
        let song = RecordingAudioPlayer()
        let scheduler = scheduler(session: session, players: [wake, song])
        scheduler.startRinging(alarmID: "song-test", preview: true)
        session.activations[0](.success(()))
        scheduler.startSolveSoundtrack(assetURL: songURL, alarmID: "song-test", volume: 1)
        scheduler.dismiss()
        session.activations[1](.success(()))

        XCTAssertEqual(song.playCount, 0)
        XCTAssertEqual(wake.stopCount, 1)
        XCTAssertFalse(scheduler.isRinging)
    }

    func testLockedSoundtrackDoesNotLoadOrActivate() {
        let settings = SettingsStore.shared
        let previous = settings.whizPlan
        settings.setWhizPlanFromEntitlement(.free)
        defer { settings.setWhizPlanFromEntitlement(previous) }
        let session = ControlledAudioSession()
        let scheduler = scheduler(session: session, players: [RecordingAudioPlayer()])
        defer { scheduler.dismiss() }
        scheduler.startRinging(alarmID: "song-test", preview: true)
        scheduler.startSolveSoundtrack(assetURL: songURL, alarmID: "song-test", volume: 1)
        XCTAssertEqual(session.activations.count, 1)
    }
}

final class AudioSessionControllerTests: XCTestCase {
    @MainActor
    func testNativePreparedPlayerCanStartAndStop() async throws {
        let controller = AudioSessionController()
        let url = try XCTUnwrap(Bundle(for: AlarmScheduler.self).url(forResource: "chime", withExtension: "caf"))
        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = 0
        let activated = expectation(description: "native activation")
        controller.activate(preparing: player) { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            activated.fulfill()
        }
        await fulfillment(of: [activated], timeout: 5)
        XCTAssertTrue(player.play())
        player.stop()
        let released = expectation(description: "native release")
        controller.deactivate { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            released.fulfill()
        }
        await fulfillment(of: [released], timeout: 5)
    }

    func testPendingActivationClientsShareTheSameSessionChange() {
        let initialStarted = expectation(description: "initial release started")
        let activationStarted = expectation(description: "shared activation started")
        let clientsCompleted = expectation(description: "both activation clients completed")
        clientsCompleted.expectedFulfillmentCount = 2
        var changes: [Bool] = []
        var completions: [(Result<Void, Error>) -> Void] = []
        let controller = AudioSessionController { active, completion in
            DispatchQueue.main.async {
                changes.append(active)
                completions.append(completion)
                if changes.count == 1 { initialStarted.fulfill() }
                if changes.count == 2 { activationStarted.fulfill() }
            }
        }
        controller.deactivate { _ in }
        wait(for: [initialStarted], timeout: 2)
        for _ in 0..<2 {
            controller.activate(preparation: {
                XCTAssertFalse(Thread.isMainThread)
            }) { result in
                if case .failure = result { XCTFail("A compatible activation must not be cancelled") }
                clientsCompleted.fulfill()
            }
        }
        completions[0](.success(()))
        wait(for: [activationStarted], timeout: 2)
        XCTAssertEqual(changes, [false, true])
        completions[1](.success(()))
        wait(for: [clientsCompleted], timeout: 2)
    }

    func testChangesRunOffMainAndCompleteOnMain() {
        let activated = expectation(description: "activated")
        let deactivated = expectation(description: "deactivated")
        let controller = AudioSessionController { active, completion in
            XCTAssertFalse(Thread.isMainThread)
            completion(active ? .success(()) : .failure(AudioTestError.refused))
        }
        controller.activate { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure = result { XCTFail("Activation should succeed") }
            activated.fulfill()
        }
        wait(for: [activated], timeout: 2)
        controller.deactivate { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .success = result { XCTFail("Deactivation error must propagate") }
            deactivated.fulfill()
        }
        wait(for: [deactivated], timeout: 2)
    }

    func testPendingChangesCoalesceWithoutOverlappingAnInFlightChange() {
        let firstStarted = expectation(description: "first change started")
        let secondStarted = expectation(description: "newest change started")
        let superseded = expectation(description: "obsolete release cancelled")
        let completed = expectation(description: "newest activation completed")
        var changes: [Bool] = []
        var completions: [(Result<Void, Error>) -> Void] = []
        let controller = AudioSessionController { active, completion in
            XCTAssertFalse(Thread.isMainThread)
            DispatchQueue.main.async {
                changes.append(active)
                completions.append(completion)
                if changes.count == 1 { firstStarted.fulfill() }
                if changes.count == 2 { secondStarted.fulfill() }
            }
        }
        controller.activate { _ in }
        wait(for: [firstStarted], timeout: 2)
        controller.deactivate { result in
            guard case .failure(let error) = result else {
                XCTFail("Obsolete release should be cancelled")
                superseded.fulfill()
                return
            }
            XCTAssertTrue(error is CancellationError)
            superseded.fulfill()
        }
        controller.activate { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure = result { XCTFail("Newest activation should succeed") }
            completed.fulfill()
        }
        wait(for: [superseded], timeout: 2)
        XCTAssertEqual(changes, [true])
        completions[0](.success(()))
        wait(for: [secondStarted], timeout: 2)
        XCTAssertEqual(changes, [true, true])
        completions[1](.success(()))
        wait(for: [completed], timeout: 2)
    }
}
