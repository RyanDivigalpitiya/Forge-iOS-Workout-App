import SwiftUI
import UserNotifications

/// Rest timer shown between sets during an active workout.
/// Uses TimelineView for periodic updates, which survives parent view re-renders
/// (unlike Timer.publish, which gets recreated and cancelled on each re-render).
///
/// Three dismissal paths:
/// - Natural expiry: parent's `onExpired` runs and should NOT cancel the pending notification
///   (system delivers it normally; cancelling races against system delivery, especially when
///   the debugger keeps the app alive in background).
/// - X button: parent's `onCancelTapped` runs and SHOULD cancel the pending notification.
/// - Done button: parent's `finishWorkout()` calls its dismiss helper which cancels the notification.
struct BreakTimerView: View {

    static let notificationIdentifier = "workoutRestTimerNotification"

    let durationSeconds: Int
    @Binding var timerVisible: Bool
    let nextExerciseName: String?
    let nextSetDescription: String?
    let onExpired: () -> Void
    let onCancelTapped: () -> Void

    @State private var breakTimerStartDate: Date? = nil
    @State private var hasExpired = false

    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var sessionClient: SessionClient

    /// True on short-screen phones (SE-class). Drives the small-screen UX:
    /// the cancel-timer X moves up to the workout's top toolbar (replacing
    /// the disabled back chevron) and the in-ring cancel button hides so
    /// the ring + Up Next + bottom safe area all fit comfortably.
    let isSmallScreen: Bool

    // Ring diameter scales with screen width but caps at 260pt so the ring
    // doesn't dominate on Pro Max. Small screens get an explicit 200pt ring
    // so the Up Next info below isn't pushed off-screen.
    // SE: 200pt, 17: ~236pt, Pro Max: 260pt.
    private var ringDiameter: CGFloat {
        if isSmallScreen { return 200 }
        return min(UIScreen.main.bounds.width * 0.60, 260)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = computeRemaining(at: context.date)
            let total = durationSeconds
            let progress = total > 0 ? CGFloat(remaining) / CGFloat(total) : 0

            VStack(spacing: 0) {
                Spacer().frame(maxHeight: 10)

                // Peer's parallel countdown — renders only when the peer is
                // also on a break. Small muted strip so it doesn't compete
                // with the primary timer for attention.
                if let peerId = sessionClient.peerIds.first,
                   let peerTimer = sessionClient.peerBreakTimer[peerId] {
                    let peerRemaining = max(0, Int(peerTimer.endDate.timeIntervalSince(context.date)))
                    let peerProfile = sessionClient.peerProfiles[peerId]
                    HStack(spacing: 8) {
                        avatar(
                            data: peerProfile?.photoData,
                            fallbackInitial: initial(from: peerProfile?.name ?? "?"),
                            diameter: 22
                        )
                        Text("Also resting · \(peerRemaining)s")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.systemGray))
                            .monospacedDigit()
                    }
                    .padding(.bottom, 30)
                }

                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(Color(.systemGray4))
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(settings.fgColor)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.linear(duration: 1), value: remaining)
                    VStack(spacing: 2) {
                        Text("Rest for")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(settings.fgColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(remaining)s")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(settings.fgColor)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    // Constrain text width so `minimumScaleFactor` actually
                    // triggers (without a width bound the text reports its
                    // natural size and never shrinks). 160pt fits "100s" at
                    // 60pt and stays well inside the ring on SE.
                    .frame(maxWidth: 160)
                }
                // Explicit ring size scales with screen width but caps so Pro
                // Max doesn't render an oversized ring. Without the explicit
                // frame the ring shrinks under vertical pressure on SE.
                .frame(width: ringDiameter, height: ringDiameter)
                .padding(.bottom, 30)

                // Up next info
                if let exerciseName = nextExerciseName, let setDescription = nextSetDescription {
                    VStack(spacing: 6) {
                        Text("Up Next")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray))
                        Text(exerciseName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        let parts = setDescription.components(separatedBy: "  →  ")
                        if parts.count == 2 {
                            (Text(parts[0]).foregroundColor(settings.fgColor) +
                             Text("  →  \(parts[1])").foregroundColor(Color(.systemGray)))
                                .font(.system(size: 19, weight: .medium))
                        } else {
                            Text(setDescription)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(Color(.systemGray))
                        }
                    }
                    .padding(.bottom, 30)
                }

                if !isSmallScreen {
                    Button(action: {
                        onCancelTapped()
                    }) {
                        ZStack {
                            Circle()
                                .frame(width: 30, height: 30)
                                .foregroundColor(Color(.systemGray4))
                            Image(systemName: "xmark")
                                .resizable()
                                .frame(width: 13, height: 13)
                                .fontWeight(.bold)
                                .foregroundColor(settings.fgColor)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .opacity(timerVisible ? 1 : 0)
            .onChange(of: remaining) { _, newValue in
                if newValue == 0 && !hasExpired {
                    hasExpired = true
                    triggerHapticFeedback()
                    onExpired()
                }
            }
        }
        .onAppear {
            breakTimerStartDate = Date()
            hasExpired = false
            sendNotification()
        }
    }

    private func computeRemaining(at date: Date) -> Int {
        guard let start = breakTimerStartDate else { return durationSeconds }
        let elapsed = date.timeIntervalSince(start)
        return max(0, durationSeconds - Int(elapsed))
    }

    private func sendNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                Log.debug("[Forge] Notifications not authorized (status: \(settings.authorizationStatus.rawValue))")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Break Timer Done"
            content.body = "Time to start your next set!"
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "workoutCategory"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(self.durationSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    Log.debug("[Forge] Notification schedule error: \(error)")
                } else {
                    Log.debug("[Forge] Scheduled notification for \(self.durationSeconds)s from now")
                }
            }
        }
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
