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

    private let fgColor = GlobalSettings.shared.fgColor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = computeRemaining(at: context.date)
            let total = durationSeconds
            let progress = total > 0 ? CGFloat(remaining) / CGFloat(total) : 0

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(Color(.systemGray4))
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(fgColor)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.linear(duration: 1), value: remaining)
                    VStack(spacing: 2) {
                        Text("Rest for")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(fgColor)
                        Text("\(remaining)s")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(fgColor)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 20)

                // Up next info
                if let exerciseName = nextExerciseName, let setDescription = nextSetDescription {
                    VStack(spacing: 6) {
                        Text("Up Next")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray))
                        Text(exerciseName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text(setDescription)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                    }
                    .padding(.bottom, 30)
                }

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
                            .foregroundColor(fgColor)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 40)
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
                print("[Forge] Notifications not authorized (status: \(settings.authorizationStatus.rawValue))")
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
                    print("[Forge] Notification schedule error: \(error)")
                } else {
                    print("[Forge] Scheduled notification for \(self.durationSeconds)s from now")
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
