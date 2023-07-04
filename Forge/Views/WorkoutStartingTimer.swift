import SwiftUI
import Combine
import UIKit


struct WorkoutStartingTimer: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////

    
    private var workoutStartingTime = 3 // 3 second timer
    let timer = Timer.publish(every: 1, on: .main, in: .common)
    @State private var remainingTime: Int = 3
    @State private var timerSubscription: Cancellable? = nil
    @State private var totalTime: Int = 3
    @State private var viewOpacity: Double = 0.0

    func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                Spacer()
                Text("Starting in ...")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(GlobalSettings.shared.fgColor)
                    .opacity(viewOpacity)
                Spacer()
            }
            Button(action: {
                remainingTime = 0
            }) {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(Color(.systemGray5))
                    Circle()
                        .trim(from: 0, to: CGFloat(remainingTime) / CGFloat(totalTime))
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(GlobalSettings.shared.fgColor)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.easeOut(duration: 1), value: remainingTime)
                    Text("\(remainingTime)")
                        .font(.system(size: 60))
                        .foregroundColor(GlobalSettings.shared.fgColor)
                        .fontWeight(.bold)
                }
                .opacity(viewOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) {
                        viewOpacity = 1.0
                    }
                    self.startTimer()

                }
                .padding(.vertical, 50)
                .onReceive(timer) { _ in
                    if remainingTime > 0 {
                        remainingTime -= 1
                        if remainingTime == 0 {
                            triggerHapticFeedback()
//                            print("reached here.")
                            withAnimation(.easeInOut(duration: 0.5)) {
                                planViewModel.isStartingTimerDone = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    planViewModel.shouldShowWorkout = true
                                }
                            }
                        }
                    } else {
                        triggerHapticFeedback()
//                        print("reached here.")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            planViewModel.isStartingTimerDone = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                planViewModel.shouldShowWorkout = true
                            }
                        }
                    }
                }
                .onAppear {
                    totalTime = remainingTime
                }
                .onDisappear {
                    timerSubscription?.cancel()
                }

            }


            Spacer()
        }
        .padding(.horizontal, 40)
    }

    func startTimer() {
        timerSubscription = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
//                triggerHapticFeedback()
//                print("reached here.")
                withAnimation(.easeInOut(duration: 0.5)) {
                    planViewModel.isStartingTimerDone = true
                    planViewModel.shouldShowWorkout = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 1)) {
                            planViewModel.isWorkoutOpacityFull = true
                            planViewModel.scrollViewScaleEffect = 1.0
                        }
                    }
                }
                timerSubscription?.cancel()
                triggerHapticFeedback()
            }
        }
    }
}


struct WorkoutStartingTimer_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutStartingTimer()
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .preferredColorScheme(.dark)
    }
}
