import SwiftUI
import Combine
import UIKit


struct WorkoutStartingTimer: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////

    
    private var workoutStartingTime = 3 // 3 second workoutStartingtimer
    let workoutStartingtimer = Timer.publish(every: 1, on: .main, in: .common)
    @State private var workoutStartingTimerRemainingTime: Int = 3
    @State private var workoutStartingTimerSubscription: Cancellable? = nil
    @State private var workoutStartingTimerTotalTime: Int = 3
    @State private var workoutTimerContentViewOpacity: Double = 0.0

    func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    var body: some View {
//        VStack(spacing: 0) {
//            Spacer()
//            HStack {
//                Spacer()
//                Text("Starting in ...")
//                    .font(.system(size: 40))
//                    .fontWeight(.bold)
//                    .foregroundColor(GlobalSettings.shared.fgColor)
//                    .opacity(workoutTimerContentViewOpacity)
//                Spacer()
//            }
//            Button(action: {
//                workoutStartingTimerRemainingTime = 0
//            }) {
//                ZStack {
//                    Circle()
//                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
//                        .foregroundColor(Color(.systemGray5))
//                    Circle()
//                        .trim(from: 0, to: CGFloat(workoutStartingTimerRemainingTime) / CGFloat(workoutStartingTimerTotalTime))
//                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
//                        .foregroundColor(GlobalSettings.shared.fgColor)
//                        .rotationEffect(Angle(degrees: -90))
//                        .animation(.easeOut(duration: 1), value: workoutStartingTimerRemainingTime)
//                    Text("\(workoutStartingTimerRemainingTime)")
//                        .font(.system(size: 60))
//                        .foregroundColor(GlobalSettings.shared.fgColor)
//                        .fontWeight(.bold)
//                }
//                .opacity(workoutTimerContentViewOpacity)
//                .onAppear {
//                    withAnimation(.easeIn(duration: 0.5)) {
//                        workoutTimerContentViewOpacity = 1.0
//                    }
//                    self.startTimer()
//
//                }
//                .padding(.vertical, 50)
//                .onReceive(workoutStartingtimer) { _ in
//                    if workoutStartingTimerRemainingTime > 0 {
//                        workoutStartingTimerRemainingTime -= 1
//                        if workoutStartingTimerRemainingTime == 0 {
//                            triggerHapticFeedback()
////                            print("reached here.")
//                            withAnimation(.easeInOut(duration: 0.5)) {
//                                isStartingTimerDone = true
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                    planViewModel.shouldShowWorkout = true
//                                }
//                            }
//                        }
//                    } else {
//                        triggerHapticFeedback()
////                        print("reached here.")
//                        withAnimation(.easeInOut(duration: 0.5)) {
//                            isStartingTimerDone = true
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                planViewModel.shouldShowWorkout = true
//                            }
//                        }
//                    }
//                }
//                .onAppear {
//                    workoutStartingTimerTotalTime = workoutStartingTimerRemainingTime
//                }
//                .onDisappear {
//                    workoutStartingTimerSubscription?.cancel()
//                }
//
//            }
//
//
//            Spacer()
//        }
//        .padding(.horizontal, 40)
//        .background(.black)
        Text("")
    }

//    func startTimer() {
//        workoutStartingTimerSubscription = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { _ in
//            if workoutStartingTimerRemainingTime > 0 {
//                workoutStartingTimerRemainingTime -= 1
//            } else {
////                triggerHapticFeedback()
////                print("reached here.")
//                withAnimation(.easeInOut(duration: 0.5)) {
//                    isStartingTimerDone = true
//                    shouldShowWorkout = true
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                        withAnimation(.easeInOut(duration: 1)) {
//                            isWorkoutOpacityFull = true
//                            scrollViewScaleEffect = 1.0
//                        }
//                    }
//                }
//                workoutStartingTimerSubscription?.cancel()
//                triggerHapticFeedback()
//            }
//        }
//    }
}


struct WorkoutStartingTimer_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutStartingTimer()
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .preferredColorScheme(.dark)
    }
}
