import SwiftUI

struct BreakTimerView: View {
    
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var stopwatchViewModel: StopwatchViewModel
    //-////////////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode
    let fgColor = GlobalSettings.shared.fgColor

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(stopwatchViewModel.breakTimeRemaining) s")
                    .font(.system(size: 70))
                    .fontWeight(.bold)
                    .foregroundColor(fgColor)
                Spacer()
            }
            Spacer()
        }
        .background(Color(.systemGray6))
        .onAppear{
            stopwatchViewModel.startTimer()
        }
        .onDisappear {
            stopwatchViewModel.stopTimer()
        }
    }
}

// break timer view functions
extension BreakTimerView {
//    func sendNotification() {
//        let center = UNUserNotificationCenter.current()
//        let content = UNMutableNotificationContent()
//        content.title = "Start your next set!"
//        content.sound = UNNotificationSound.default
//        content.categoryIdentifier = "workoutCategory"
//
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingTime), repeats: false)
//        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
//        center.add(request) { (error) in
//            if let error = error {
//                print("Error scheduling notification: \(error)")
//            }
//        }
//    }

    func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

}

struct BreakTimerView_Previews: PreviewProvider {
    static var previews: some View {
        BreakTimerView()
            .environmentObject(StopwatchViewModel())
            .preferredColorScheme(.dark)

    }
}
