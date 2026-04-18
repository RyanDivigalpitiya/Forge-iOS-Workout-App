import WatchConnectivity
import WatchKit

/// Manages the watch side of WatchConnectivity and owns the single haptic-only
/// break-timer expiry path.
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

    @Published private(set) var timerState: TimerState = .idle

    // Tracks the endDate of the most recently processed timerStarted message so
    // duplicate deliveries (sendMessage + applicationContext) don't double-process.
    private var lastHandledEndDate: Date?
    private var expiryTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func activateSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func expireTimerFromCountdown(endDate: Date, playHaptic: Bool) {
        guard case let .counting(currentEndDate, _, exerciseName, setDescription) = timerState,
              currentEndDate == endDate else { return }

        expiryTask?.cancel()
        expiryTask = nil
        timerState = .expired(exerciseName: exerciseName, setDescription: setDescription)

        if playHaptic {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func syncExpiredStateIfNeeded(for endDate: Date) {
        if Date() >= endDate {
            expireTimerFromCountdown(endDate: endDate, playHaptic: false)
        }
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

            // Dedupe: the phone sends the same payload via both sendMessage and
            // updateApplicationContext. Skip if we already handled this exact timer.
            if lastHandledEndDate == endDate { return }
            lastHandledEndDate = endDate

            if endDate > Date() {
                // Future timer — start counting and arm the direct watch-side
                // expiry task that will fire the haptic at the end date.
                expiryTask?.cancel()
                timerState = .counting(endDate: endDate, duration: duration,
                                      exerciseName: exerciseName,
                                      setDescription: setDescription)
                scheduleExpiryTask(for: endDate)
            } else {
                // Stale message from a previous session (e.g. via receivedApplicationContext).
                // Do NOT transition to .expired or fire a haptic — user would get a phantom
                // alert for a timer that expired hours ago.
                timerState = .idle
            }

        case "timerDismissed":
            expiryTask?.cancel()
            expiryTask = nil
            timerState = .idle
            lastHandledEndDate = nil

        case "workoutStarted":
            // Start an HKWorkoutSession on the watch to keep the app alive for
            // the workout duration so the break-timer haptic can fire on time.
            WatchWorkoutRuntime.shared.startWorkout()

        case "workoutEnded":
            expiryTask?.cancel()
            expiryTask = nil
            timerState = .idle
            lastHandledEndDate = nil
            WatchWorkoutRuntime.shared.endWorkout()

        default:
            break
        }
    }

    // MARK: - Expiry Scheduling

    private func scheduleExpiryTask(for endDate: Date) {
        let delay = endDate.timeIntervalSinceNow
        guard delay > 0 else {
            expireTimerFromCountdown(endDate: endDate, playHaptic: true)
            return
        }

        expiryTask = Task { [weak self] in
            let duration = UInt64(delay * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: duration)
            } catch {
                return
            }

            await MainActor.run {
                self?.expireTimerFromCountdown(endDate: endDate, playHaptic: true)
            }
        }
    }
}
