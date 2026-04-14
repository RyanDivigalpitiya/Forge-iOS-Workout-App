import WatchConnectivity
import WatchKit

/// Manages the watch side of WatchConnectivity, receiving break timer state from the iPhone.
/// Singleton — activated once in `ForgeWatchApp.init()`.
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSessionManager()

    enum TimerState: Equatable {
        case idle
        case counting(endDate: Date, duration: Int,
                      exerciseName: String, setDescription: String)
        case expired(exerciseName: String, setDescription: String)

        static func == (lhs: TimerState, rhs: TimerState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case let (.counting(e1, d1, n1, s1), .counting(e2, d2, n2, s2)):
                return e1 == e2 && d1 == d2 && n1 == n2 && s1 == s2
            case let (.expired(n1, s1), .expired(n2, s2)):
                return n1 == n2 && s1 == s2
            default:
                return false
            }
        }
    }

    @Published var timerState: TimerState = .idle

    private override init() {
        super.init()
    }

    func activateSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("[ForgeWatch] WCSession activation error: \(error.localizedDescription)")
            return
        }
        print("[ForgeWatch] WCSession activated (state: \(activationState.rawValue))")

        // Pick up any state sent while the watch app was not running.
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            DispatchQueue.main.async { self.handleMessage(context) }
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handleMessage(message) }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.handleMessage(applicationContext) }
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "timerStarted":
            guard let endTimestamp = message["endDate"] as? TimeInterval,
                  let duration = message["duration"] as? Int else { return }
            let endDate = Date(timeIntervalSince1970: endTimestamp)
            let exerciseName = message["exerciseName"] as? String ?? ""
            let setDescription = message["setDescription"] as? String ?? ""

            if endDate <= Date() {
                // Timer already expired — go straight to expired state.
                timerState = .expired(exerciseName: exerciseName,
                                     setDescription: setDescription)
                playHaptic()
            } else {
                timerState = .counting(endDate: endDate, duration: duration,
                                      exerciseName: exerciseName,
                                      setDescription: setDescription)
            }

        case "timerDismissed", "workoutEnded":
            timerState = .idle

        default:
            break
        }
    }

    func playHaptic() {
        WKInterfaceDevice.current().play(.notification)
    }
}
