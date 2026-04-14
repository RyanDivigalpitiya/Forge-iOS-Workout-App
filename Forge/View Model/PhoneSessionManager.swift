import WatchConnectivity

/// Manages the phone side of WatchConnectivity, sending break timer state to the Apple Watch.
/// Singleton — activated once in `ForgeApp.init()` and called from `WorkoutInProgressView`.
final class PhoneSessionManager: NSObject, WCSessionDelegate {

    static let shared = PhoneSessionManager()

    private override init() {
        super.init()
    }

    func activateSession() {
        guard WCSession.isSupported() else {
            print("[Forge] WCSession not supported on this device")
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

    func sendWorkoutEnded() {
        send(["type": "workoutEnded"])
    }

    // MARK: - Private

    private func send(_ payload: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("[Forge] WC sendMessage error: \(error.localizedDescription)")
            }
        }

        // Guaranteed eventual delivery — latest state wins.
        try? WCSession.default.updateApplicationContext(payload)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("[Forge] WCSession activation error: \(error.localizedDescription)")
        } else {
            print("[Forge] WCSession activated (state: \(activationState.rawValue))")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after the user switches Apple Watches.
        session.activate()
    }
}
