import Combine
import Foundation
import WatchConnectivity

/// Identifies a single watch-originated set-completion tap. Each tap mints a
/// fresh `id` so two consecutive taps with identical indices both fire the
/// `@Published` subscriber on the phone side.
struct SetCompletionRequest: Identifiable, Equatable {
    let id = UUID()
    let exerciseIndex: Int
    let setIndex: Int
}

/// Manages the phone side of WatchConnectivity, sending break timer state to the Apple Watch.
/// Singleton — activated once in `ForgeApp.init()` and called from `WorkoutInProgressView`.
final class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = PhoneSessionManager()

    /// Watch-originated tap on the Complete button. Subscribed by
    /// `WorkoutInProgressView` and validated against the current workout state
    /// before being routed into `handleSetTap`.
    @Published var setCompletedFromWatch: SetCompletionRequest?

    private override init() {
        super.init()
    }

    func activateSession() {
        guard WCSession.isSupported() else {
            Log.debug("[Forge] WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Outgoing Messages

    func sendTimerStarted(endDate: Date, duration: Int,
                          exerciseName: String?, setDescription: String?) {
        let payload: [String: Any] = [
            "type": "timerStarted",
            "endDate": endDate.timeIntervalSince1970,
            "duration": duration,
            "exerciseName": exerciseName ?? "",
            "setDescription": setDescription ?? ""
        ]
        send(payload)
    }

    func sendTimerDismissed() {
        send(["type": "timerDismissed"])
    }

    func sendWorkoutStarted() {
        send(["type": "workoutStarted"])
    }

    func sendWorkoutEnded() {
        send(["type": "workoutEnded"])
    }

    /// Pushes the user's "next set" descriptor to the watch so it can render an
    /// idle next-set view + Complete button when no break timer is active.
    /// When `isAwaitingFinish` is true, every set is complete and the watch
    /// should render the "finish on iPhone" message instead of a button.
    func sendNextSetInfo(exerciseIndex: Int, setIndex: Int,
                         exerciseName: String, setDescription: String,
                         isAwaitingFinish: Bool) {
        let payload: [String: Any] = [
            "type": "nextSetInfo",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "exerciseName": exerciseName,
            "setDescription": setDescription,
            "isAwaitingFinish": isAwaitingFinish
        ]
        send(payload)
    }

    // MARK: - Private

    private func send(_ payload: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                Log.debug("[Forge] WC sendMessage error: \(error.localizedDescription)")
            }
        }

        // Guaranteed eventual delivery — latest state wins.
        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            Log.debug("[Forge] WC updateApplicationContext error: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            Log.debug("[Forge] WCSession activation error: \(error.localizedDescription)")
        } else {
            Log.debug("[Forge] WCSession activated (state: \(activationState.rawValue))")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after the user switches Apple Watches.
        session.activate()
    }

    // MARK: - Inbound (watch → phone)

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handleInbound(message) }
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { self.handleInbound(userInfo) }
    }

    private func handleInbound(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "setCompletedFromWatch":
            guard let exerciseIndex = message["exerciseIndex"] as? Int,
                  let setIndex = message["setIndex"] as? Int else { return }
            // Fresh request id per tap so consecutive taps with identical
            // indices each fire the `@Published` subscriber.
            setCompletedFromWatch = SetCompletionRequest(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex
            )
        default:
            break
        }
    }
}
