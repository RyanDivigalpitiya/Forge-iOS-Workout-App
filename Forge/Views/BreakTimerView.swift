import SwiftUI
import Combine
import UserNotifications

/// 60-second rest timer shown between sets during an active workout.
/// Owns its own timer state (`remainingTime`, `totalTime`, `breakTimerStartDate`, `timerSubscription`)
/// and notification scheduling. The parent retains visibility coordination via `timerVisible` and
/// reacts to expiry/cancellation via the two callbacks.
///
/// Three dismissal paths:
/// - Natural expiry: parent's `onExpired` runs and should NOT cancel the pending notification
///   (system delivers it normally; cancelling races against system delivery, especially when
///   the debugger keeps the app alive in background).
/// - X button: parent's `onCancelTapped` runs and SHOULD cancel the pending notification.
/// - Done button: parent's `finishWorkout()` calls its dismiss helper which cancels the notification.
struct BreakTimerView: View {

    static let notificationIdentifier = "workoutRestTimerNotification"

    @Binding var timerVisible: Bool

    let durationSeconds: Int
    let onExpired: () -> Void
    let onCancelTapped: () -> Void

    @State private var remainingTime: Int
    @State private var totalTime: Int
    @State private var breakTimerStartDate: Date? = nil
    @State private var timerSubscription: Cancellable? = nil

    private let timer = Timer.publish(every: 1, on: .main, in: .common)
    private let fgColor = GlobalSettings.shared.fgColor

    init(durationSeconds: Int,
         timerVisible: Binding<Bool>,
         onExpired: @escaping () -> Void,
         onCancelTapped: @escaping () -> Void) {
        self.durationSeconds = durationSeconds
        self._timerVisible = timerVisible
        self.onExpired = onExpired
        self.onCancelTapped = onCancelTapped
        self._remainingTime = State(initialValue: durationSeconds)
        self._totalTime = State(initialValue: durationSeconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                Spacer()
                Text("Rest for ")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(fgColor)
                Spacer()
            }

            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .foregroundColor(Color(.systemGray4))
                Circle()
                    .trim(from: 0, to: CGFloat(remainingTime) / CGFloat(totalTime))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .foregroundColor(fgColor)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 1), value: remainingTime)
                Text("\(remainingTime) s")
                    .font(.system(size: 60))
                    .foregroundColor(fgColor)
                    .fontWeight(.bold)
            }
            .padding(.vertical, 50)
            .onReceive(timer) { _ in
                updateRemainingTime()
                if remainingTime == 0 {
                    triggerHapticFeedback()
                    onExpired()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                updateRemainingTime()
            }
            .onAppear {
                remainingTime = durationSeconds
                totalTime = remainingTime
                breakTimerStartDate = Date()
                sendNotification()
                timerSubscription = timer.connect()
            }
            .onDisappear {
                timerSubscription?.cancel()
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
    }

    private func updateRemainingTime() {
        guard let breakTimerStartDate else { return }
        let elapsedTime = Date().timeIntervalSince(breakTimerStartDate)
        let newRemainingTime = max(0, totalTime - Int(elapsedTime))
        remainingTime = newRemainingTime
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

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(self.remainingTime), repeats: false)
            let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("[Forge] Notification schedule error: \(error)")
                } else {
                    print("[Forge] Scheduled notification for \(self.remainingTime)s from now")
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
