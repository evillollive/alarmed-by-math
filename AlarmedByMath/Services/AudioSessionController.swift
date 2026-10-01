import AVFoundation
import Foundation

protocol AudioSessionControlling: AnyObject {
    /// Completions are delivered on the main queue.
    func activate(preparation: @escaping () throws -> Void, completion: @escaping (Result<Void, Error>) -> Void)
    func deactivate(completion: @escaping (Result<Void, Error>) -> Void)
}

extension AudioSessionControlling {
    func activate(completion: @escaping (Result<Void, Error>) -> Void) {
        activate(preparation: {}, completion: completion)
    }

    func activate(preparing player: any AlarmAudioPlaying, completion: @escaping (Result<Void, Error>) -> Void) {
        activate(preparation: {
            guard player.prepareToPlay() else { throw AudioPreparationError.failed }
        }, completion: completion)
    }
}

private enum AudioPreparationError: LocalizedError {
    case failed

    var errorDescription: String? { "The audio player could not prepare its output." }
}

protocol AlarmAudioPlaying: AnyObject {
    var duration: TimeInterval { get }
    var numberOfLoops: Int { get set }
    var volume: Float { get set }
    func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func stop()
}

extension AVAudioPlayer: AlarmAudioPlaying {}

final class AudioSessionController: AudioSessionControlling {
    static let shared = AudioSessionController()
    typealias Change = (Bool, @escaping (Result<Void, Error>) -> Void) -> Void

    private struct Client {
        let preparation: (() throws -> Void)?
        let completion: (Result<Void, Error>) -> Void
    }

    private struct Request {
        let active: Bool
        var clients: [Client]
    }

    private let queue = DispatchQueue(label: "com.alarmedbymath.audio-session", qos: .userInitiated)
    private let performChange: Change
    private var requests: [Request] = []
    private var isChanging = false

    init(performChange: @escaping Change = AudioSessionController.changeSystemSession) {
        self.performChange = performChange
    }

    func activate(preparation: @escaping () throws -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        enqueue(active: true, preparation: preparation, completion: completion)
    }

    func deactivate(completion: @escaping (Result<Void, Error>) -> Void) {
        enqueue(active: false, preparation: nil, completion: completion)
    }

    private func enqueue(active: Bool, preparation: (() throws -> Void)?, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            let client = Client(preparation: preparation, completion: completion)
            if let last = self.requests.indices.last, self.requests[last].active == active {
                self.requests[last].clients.append(client)
                return
            }
            let superseded = self.requests
            self.requests = [Request(active: active, clients: [client])]
            for request in superseded {
                DispatchQueue.main.async {
                    request.clients.forEach { $0.completion(.failure(CancellationError())) }
                }
            }
            self.startNext()
        }
    }

    private func startNext() {
        guard !isChanging, !requests.isEmpty else { return }
        isChanging = true
        let request = requests.removeFirst()
        // Native async calls must finish before the next session change starts.
        performChange(request.active) { result in
            self.queue.async {
                let results: [Result<Void, Error>] = request.clients.map { client in
                    guard case .success = result else { return result }
                    do {
                        try client.preparation?()
                        return .success(())
                    } catch {
                        return .failure(error)
                    }
                }
                DispatchQueue.main.async {
                    for (client, result) in zip(request.clients, results) {
                        client.completion(result)
                    }
                    // A cancelled client's prepared player must stop before release.
                    self.queue.async {
                        self.isChanging = false
                        self.startNext()
                    }
                }
            }
        }
    }

    private static func changeSystemSession(active: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let session = AVAudioSession.sharedInstance()
        do {
            if active {
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            }
            if #available(iOS 27.0, *) {
                let finish: (Bool, Error?) -> Void = { succeeded, error in
                    if let error {
                        completion(.failure(error))
                    } else if succeeded {
                        completion(.success(()))
                    } else {
                        completion(.failure(SessionError.changeRejected(active: active)))
                    }
                }
                if active {
                    session.activate(options: [], completionHandler: finish)
                } else {
                    session.deactivate(options: .notifyOthersOnDeactivation, completionHandler: finish)
                }
            } else {
                try session.setActive(active, options: active ? [] : .notifyOthersOnDeactivation)
                completion(.success(()))
            }
        } catch {
            completion(.failure(error))
        }
    }

    private enum SessionError: LocalizedError {
        case changeRejected(active: Bool)

        var errorDescription: String? {
            switch self {
            case .changeRejected(let active):
                return active ? "The system did not activate alarm audio." : "The system did not release alarm audio."
            }
        }
    }
}
