import SwiftUI

struct BreakTimerView: View {
    
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var stopwatchViewModel: StopwatchViewModel
    //-////////////////////////////////////////////////////////
    
    private var breakDuration = 60
    
    @Environment(\.presentationMode) var presentationMode
    let fgColor = GlobalSettings.shared.fgColor

    var body: some View {
        VStack {
            Spacer()
            Text("Rest for ")
                .font(.system(size: 40))
                .fontWeight(.bold)
                .padding(.bottom,30)
                .foregroundColor(.white)
            
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .foregroundColor(Color(.systemGray5))
                Circle()
                    .trim(from: 0, to: CGFloat(stopwatchViewModel.breakTimeRemaining) / CGFloat(breakDuration))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .foregroundColor(GlobalSettings.shared.fgColor)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 1), value: stopwatchViewModel.breakTimeRemaining)
                Text("\(stopwatchViewModel.breakTimeRemaining) s")
                    .font(.system(size: 60))
                    .foregroundColor(GlobalSettings.shared.fgColor)
                    .fontWeight(.bold)
            }
            Button(action: {
                // Dismiss the view
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .font(.system(size: 15))
                    .fontWeight(.heavy)
                    .padding([.leading, .trailing], 18)
                    .padding([.top, .bottom], 11)
                    .background(Color(.systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(1000)
            }
            .padding(.top, 20)
            Spacer()
        }
        .padding(40)
        .background(Color(.systemGray6))
        .onAppear{
            stopwatchViewModel.startTimer()
            stopwatchViewModel.sendNotification()
        }
        .onDisappear {
            stopwatchViewModel.stopTimer()
        }
        .onReceive(stopwatchViewModel.breakTimeElapsedPublisher) { elapsed in
            if elapsed {
                presentationMode.wrappedValue.dismiss()
            }
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
