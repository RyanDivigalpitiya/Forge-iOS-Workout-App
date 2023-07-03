import SwiftUI
import Combine
import UIKit

struct BreakTimerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var remainingTime: Int = 60
    @State private var timerSubscription: Cancellable? = nil
    @State private var totalTime: Int = 60
    @State private var appState: UIApplication.State = UIApplication.shared.applicationState
    @State private var startDate = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common)

    var body: some View {
        VStack {
            Spacer()
            HStack{
                Spacer()
                Text("Rest for ")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .padding(.bottom,30)
                    .foregroundColor(GlobalSettings.shared.fgColor)
                Spacer()
            }
            
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(Color(.systemGray5))
                Circle()
                    .trim(from: 0, to: CGFloat(remainingTime) / CGFloat(totalTime))
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(GlobalSettings.shared.fgColor)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 1), value: remainingTime)
                Text("\(remainingTime) s")
                    .font(.system(size: 60))
                    .foregroundColor(GlobalSettings.shared.fgColor)
                    .fontWeight(.bold)
            }
            .onReceive(timer) { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    triggerHapticFeedback()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                updateRemainingTime()
            }

            .onAppear {
                totalTime = remainingTime
                sendNotification()
                timerSubscription = timer.connect()
            }
            .onDisappear {
                timerSubscription?.cancel()
            }
            
            Button(action: {
                // Cancel timer subscription
                timerSubscription?.cancel()

                // Remove scheduled notification
                let center = UNUserNotificationCenter.current()
                center.getPendingNotificationRequests { requests in
                    let idsToRemove = requests.filter { $0.content.categoryIdentifier == "workoutCategory" }.map { $0.identifier }
                    center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                }

                // Dismiss the view
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel Timer")
                    .font(.system(size: 18))
                    .fontWeight(.heavy)
                    .padding([.leading, .trailing], 19)
                    .padding([.top, .bottom], 13)
                    .background(GlobalSettings.shared.fgColor)
                    .foregroundColor(.white)
                    .cornerRadius(1000)
            }
            .padding(.top, 90)
            Spacer()
        }
        .padding(.horizontal, 40)
        .background(.black)
    }
}

// break timer view functions
extension BreakTimerView {
    func sendNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Start your next set!"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "workoutCategory"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingTime), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    func updateRemainingTime() {
        let elapsedTime = Date().timeIntervalSince(startDate)
        let newRemainingTime = max(0, totalTime - Int(elapsedTime))
        remainingTime = newRemainingTime
    }

    func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

}

struct BreakTimerView_Previews: PreviewProvider {
    static var previews: some View {
        BreakTimerView()
            .preferredColorScheme(.dark)

    }
}
