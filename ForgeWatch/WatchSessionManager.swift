import WatchConnectivity
import WatchKit
import UserNotifications

/// Manages the watch side of WatchConnectivity, receiving break timer state from the iPhone.
/// Schedules a local notification at `endDate` so the haptic fires even when the watch app
/// is backgrounded (TimelineView-based timers only update in foreground).
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate, UNUserNotificationCenterDelegate {

    static let shared = WatchSessionManager()
    static let expiryNotificationIdentifier = "watchBreakTimerExpiry"

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

    // Tracks the endDate of the most recently processed timerStarted message so
    // duplicate deliveries (sendMessage + applicationContext) don't double-process.
    private var lastHandledEndDate: Date?

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

            // Dedupe: the phone sends the same payload via both sendMessage and
            // updateApplicationContext. Skip if we already handled this exact timer.
            if lastHandledEndDate == endDate { return }
            lastHandledEndDate = endDate

            if endDate > Date() {
                // Future timer — start counting & schedule haptic via local notification
                // so the haptic fires regardless of foreground/background state.
                timerState = .counting(endDate: endDate, duration: duration,
                                      exerciseName: exerciseName,
                                      setDescription: setDescription)
                scheduleExpiryNotification(at: endDate, exerciseName: exerciseName)
            } else {
                // Stale message from a previous session (e.g. via receivedApplicationContext).
                // Do NOT transition to .expired or fire a haptic — user would get a phantom
                // alert for a timer that expired hours ago.
                timerState = .idle
            }

        case "timerDismissed":
            timerState = .idle
            lastHandledEndDate = nil
            cancelExpiryNotification()

        case "workoutStarted":
            // Start an HKWorkoutSession on the watch to keep the app alive for
            // the workout duration so the break-timer TimelineView fires its
            // expiry haptic the instant the countdown hits zero.
            WatchWorkoutRuntime.shared.startWorkout()

        case "workoutEnded":
            timerState = .idle
            lastHandledEndDate = nil
            cancelExpiryNotification()
            WatchWorkoutRuntime.shared.endWorkout()

        default:
            break
        }
    }

    // MARK: - Local Notification Scheduling

    private func scheduleExpiryNotification(at endDate: Date, exerciseName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.expiryNotificationIdentifier])

        let timeInterval = endDate.timeIntervalSinceNow
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Break Timer Done"
        content.body = exerciseName.isEmpty ? "Time to start your next set!" : "Up next: \(exerciseName)"
        content.sound = .default   // Triggers haptic on watch

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.expiryNotificationIdentifier,
                                            content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("[ForgeWatch] Notification schedule error: \(error.localizedDescription)")
            } else {
                print("[ForgeWatch] Scheduled expiry notification for \(Int(timeInterval))s from now")
            }
        }
    }

    private func cancelExpiryNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.expiryNotificationIdentifier])
    }

    // MARK: - UNUserNotificationCenterDelegate

    // In foreground, suppress the banner but keep sound/haptic so the haptic still fires
    // without obscuring the countdown view with a banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound])
    }
}
