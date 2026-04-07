import SwiftUI
import Combine
import UIKit

struct WorkoutInProgressView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////
    
    
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    @State var selectedDetent: PresentationDetent = .medium
    @State var percentCompleted: Int = 0

    // Break timer coordination state — BreakTimerView owns its own timer state.
    // The parent retains these to coordinate the scroll-view shrink/grow animation.
    @State private var topToolBarHeight: CGFloat = 140
    @State private var topToolBarCornerRadius: CGFloat = 0
    @State private var timerEnabled = false      // gates whether BreakTimerView is rendered
    @State private var timerVisible = false      // controls BreakTimerView's opacity
    @State private var isScrollViewDisabled = false
    @State private var startDate = Date()

    // Animation + Feedback parameters
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var popScaleEffect: CGFloat = 1.0
    private var popUpScaleSize: CGFloat = 1.05
    private var popDownScaleSize: CGFloat = 0.95
    let popAnimationSpeed: Double = 0.05
    let popAnimationDelay: Double = 0.05
    @State private var isDoneCheckMarkVisible: Bool = false
    @State private var scrollViewVisible = true
    // Starting timer transition state — flipped by StartingCountdownView's onCompletion
    @State var shouldShowWorkout: Bool = false
    @State var isWorkoutOpacityFull: Bool = false
    @State var scrollViewScaleEffect: CGFloat = 0.95


    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray = GlobalSettings.shared.darkGray
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize = GlobalSettings.shared.setButtonSize
    let setsFontSize = GlobalSettings.shared.setsFontSize
    let setsSpacing = GlobalSettings.shared.setsSpacing
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    @State private var isWorkoutDone: Bool = false
    
    var body: some View {
        ZStack {
            // Workout In Progress Content
            if shouldShowWorkout{
                ZStack {
                    // EXERCISE LIST CONTAINER
                    VStack {
                        ScrollView {
                            
                            LazyVStack {
                                Spacer().frame(height: 95)
                                
                                // EXERCISE LIST
                                ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { exerciseIndex in
                                    
                                    VStack {
                                        
                                        // EXERCISE NAME + LOG CHANGE BUTTON
                                        HStack {
                                            Text(planViewModel.activePlan.exercises[exerciseIndex].name)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .font(.system(size: 30))
                                            Spacer()
                                            
                                            // LOG CHANGE BUTTON
                                            Button(action: {
                                                exerciseViewModel.activeExerciseMode = .log
                                                exerciseViewModel.activeExercise = planViewModel.activePlan.exercises[exerciseIndex]
                                                exerciseViewModel.activeExerciseIndex = exerciseIndex
                                                self.exerciseEditorIsPresented = true
                                            }) {
                                                Image(systemName: "plusminus.circle.fill")
                                                    .resizable()
                                                    .frame(width: 25, height: 25)
                                                    .foregroundColor(fgColor)
                                                    .padding(.top,5)
                                                    .padding(.trailing, 8)
                                            }
                                            .sheet(isPresented: $exerciseEditorIsPresented) {
                                                
                                                ExerciseEditorView(selectedDetent: $selectedDetent)
                                                    .presentationDetents([.medium, .large], selection: $selectedDetent)
                                                    .presentationDragIndicator(.hidden)
                                                    .environment(\.colorScheme, .dark)
                                                
                                            }

                                        }
                                        
                                        // EXERCISE SETS
                                        VStack(spacing: 0){
                                            ForEach(planViewModel.activePlan.exercises[exerciseIndex].sets.indices, id: \.self) { setIndex in
                                                HStack(spacing: 0) {
                                                    // SET BUTTON
                                                    // marks set.completed to TRUE OR FALSE
                                                    Button(action: {
                                                        
                                                        withAnimation(.easeOut(duration: 0.2)) {
                                                            planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed.toggle()
                                                            if planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed {
                                                                popUp()
                                                            } else {
                                                                popDown()
                                                            }
                                                            
                                                            if !planViewModel.activePlan.exercises[exerciseIndex].completed {
                                                                if planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed {
                                                                    isScrollViewDisabled = true
                                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                        withAnimation(.easeInOut(duration: 0.5)) {
                                                                            scrollViewScaleEffect = 0.95
                                                                            scrollViewVisible = false
                                                                            topToolBarHeight = screenHeight*0.8
                                                                            topToolBarCornerRadius = 30
                                                                            timerEnabled = true
                                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                                withAnimation(.easeInOut(duration: 0.5)) {
                                                                                    timerVisible = true
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            
                                                            feedbackGenerator.impactOccurred()
                                                            calcPercentCompleted()
                                                        }
                                                    }) {
                                                        if planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed {
                                                            ZStack {
                                                                Image("Checkmark")
                                                                    .resizable()
                                                                    .frame(width: 13, height: 11)
                                                                    .padding(.top,1)
                                                                    .padding(.trailing, 16)
                                                                Circle()
                                                                    .stroke(lineWidth: 2)
                                                                    .frame(width: setButtonSize, height: setButtonSize)
                                                                    .foregroundColor(fgColor)
                                                                    .padding(.trailing, 16)
                                                            }
                                                            .opacity(0.5)
                                                        } else {
                                                            Circle()
                                                                .stroke(lineWidth: 2)
                                                                .frame(width: setButtonSize, height: setButtonSize)
                                                                .foregroundColor(fgColor)
                                                                .padding(.trailing, 16)
                                                        }
                                                
                                                    }
                                                    .padding(.trailing, 3)

                                                    
                                                    SetView(
                                                        content: .individual(
                                                            set: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex],
                                                            index: setIndex
                                                        ),
                                                        appearance: .workoutActive(
                                                            isCompleted: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
                                                        )
                                                    )
                                                }
                                                
                                                if setIndex < planViewModel.activePlan.exercises[exerciseIndex].sets.count - 1 {
                                                    HStack{
                                                        VStack(spacing: 0) {
                                                            Rectangle().frame(width: 1, height: 12).foregroundColor(darkGray)
                                                            Circle().frame(width: 6, height: 6).foregroundColor(darkGray).padding(.vertical, 8)
                                                            Rectangle().frame(width: 1, height: 12).foregroundColor(darkGray)
                                                        }
                                                        .frame(width: setButtonSize)
                                                        .padding(.vertical,8)
                                                        Text("Rest ( 1 Minute )")
                                                            .font(.system(size: 14))
                                                            .fontWeight(.bold)
                                                            .foregroundColor(darkGray)
                                                            .padding(.vertical, 15)
                                                            .padding(.leading, 10)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        }

                                    }
                                    .padding(17) //.padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
                                    .background(bgColor)
                                    .cornerRadius(16)
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
    
                                Spacer().frame(height: 80)
                            }
                        }
                        .opacity(scrollViewVisible ? 1 : 0.5)
                        .disabled(isScrollViewDisabled)
                    }
                    .scaleEffect(scrollViewScaleEffect)
                    
                    // Top Toolbar
                    VStack(spacing:0) {
                        VStack(spacing:0) { //extra vstack required for blur effect
                            
                            Spacer().frame(height: 75)
                            
                            // Plan name + %complete + stop watch
                            VStack(spacing:0) {
                                HStack {
                                    Spacer()
                                    Text("\(planViewModel.activePlan.name)")
                                        .font(.system(size: 30))
                                        .fontWeight(.bold)
                                        .foregroundColor(fgColor)
                                    Spacer()
                                }
                                .padding(.bottom,1)
                                
                                HStack(spacing:0) {
                                    Spacer()
                                    
                                    Text("\(percentCompleted)% Complete")
                                        .fontWeight(.bold)

                                    Spacer()
                                }
                                .padding(.bottom, 10)
                                .padding(.top,5)
                                .scaleEffect(popScaleEffect)
                            }
                            .frame(height: 130)
                            
                            Spacer()
                            if timerEnabled {
                                BreakTimerView(
                                    durationSeconds: GlobalSettings.shared.breakDuration,
                                    timerVisible: $timerVisible,
                                    onExpired: {
                                        // do NOT cancel the pending notification on natural expiry —
                                        // it has either already fired or is about to, and cancelling
                                        // would race against system delivery.
                                        dismissBreakTimerView(cancelPendingNotification: false)
                                    },
                                    onCancelTapped: {
                                        dismissBreakTimerView()
                                    }
                                )
                            }
                        }
                        .frame(height: topToolBarHeight)
        //                .padding(.bottom, 15)
                        .background(BlurView(style: .systemChromeMaterial))
                        .cornerRadius(topToolBarCornerRadius)
                        
                        Spacer()
                    }
                    .edgesIgnoringSafeArea(.top)
                    
                    WorkoutBottomToolbarView(
                        exerciseEditorIsPresented: $exerciseEditorIsPresented,
                        reorderDeleteViewPresented: $reorderDeleteViewPresented,
                        selectedDetent: $selectedDetent,
                        isDoneCheckMarkVisible: isDoneCheckMarkVisible,
                        timerEnabled: timerEnabled,
                        onAddTapped: {
                            exerciseViewModel.activeExercise = Exercise()
                            exerciseViewModel.activeExerciseMode = .add
                            exerciseEditorIsPresented = true
                        },
                        onDoneTapped: {
                            finishWorkout()
                        }
                    )
                    .edgesIgnoringSafeArea(.bottom)
                }
                .opacity(isWorkoutOpacityFull ? 1 : 0)
                .background(.black)
                .onAppear {
                    calcPercentCompleted()
                    startDate = Date()
                }
            }
            
            if !shouldShowWorkout {
                StartingCountdownView(initialSeconds: 3) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        shouldShowWorkout = true
                        withAnimation(.easeInOut(duration: 1)) {
                            isWorkoutOpacityFull = true
                            scrollViewScaleEffect = 1.0
                        }
                    }
                }
            }
        }
        .disabled(isWorkoutDone)
    }
}

// % Complete label + animation functions
extension WorkoutInProgressView {

    func finishWorkout() {
        // stop timers
        dismissBreakTimerView()
        isWorkoutDone = true

        // save completed workout to persistant storage
        let completedWorkout = CompletedWorkout(
            date: Date(),
            workout: planViewModel.activePlan,
            elapsedTime: Date().timeIntervalSince(startDate),
            completion: "\(percentCompleted)%"
        )
        completedWorkoutsViewModel.completedWorkouts.append(completedWorkout)
        completedWorkoutsViewModel.saveCompletedWorkouts()

        // update workout plans with any changes made to active workout plan during workout in progress
        // (ie. log changes + added/re-ordered exercises). First, reset set completions.
        for exerciseIndex in planViewModel.activePlan.exercises.indices {
            for setIndex in planViewModel.activePlan.exercises[exerciseIndex].sets.indices {
                planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed = false
            }
            planViewModel.activePlan.exercises[exerciseIndex].completed = false
        }

        // save workout plan to persistant storage
        planViewModel.activePlan.lastCompleted = Date()
        if planViewModel.workoutPlans.indices.contains(planViewModel.activePlanIndex) {
            planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
        }
        planViewModel.savePlans()

        triggerHapticFeedback()
        withAnimation(.easeInOut(duration: 1)) {
            isDoneCheckMarkVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dismiss()
            // after dismissing this view, send user back to CompletedWorkoutsView
            completedWorkoutsViewModel.isSelectPlanViewActive = false
        }
    }

    func dismissBreakTimerView(cancelPendingNotification: Bool = true) {
        print("[Forge] dismissBreakTimerView called (cancelPendingNotification: \(cancelPendingNotification))")

        // Remove scheduled notification only when the user explicitly dismisses the
        // timer (X button or Done). On natural expiry, the notification has either
        // already fired or is suppressed by AppDelegate's willPresent handler, so
        // cancellation is unnecessary and would race against system delivery.
        if cancelPendingNotification {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [BreakTimerView.notificationIdentifier])
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            timerVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isScrollViewDisabled = false
                scrollViewVisible = true
                scrollViewScaleEffect = 1.0
                timerEnabled = false       // removes BreakTimerView from view tree → its onDisappear cancels its timer subscription
                topToolBarHeight = 140
                topToolBarCornerRadius = 0
            }
        }
    }

    func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    
    private func calcPercentCompleted() {
        var totalSets = 0
        var completedSets = 0
        for exercise in planViewModel.activePlan.exercises {
            for set in exercise.sets {
                totalSets += 1
                if set.completed {
                    completedSets += 1
                }
            }
        }
        
        if !(totalSets == 0 ){
            let  workoutCompletion = (Float(completedSets) / Float(totalSets))
            let workoutCompletionInt = Int(workoutCompletion*100)
            self.percentCompleted = workoutCompletionInt
        }  else  {
            self.percentCompleted = 0
        }
    }

    private func popUp() {
        withAnimation(.easeInOut(duration: popAnimationSpeed)) {
            popScaleEffect = popUpScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: popAnimationSpeed).delay(popAnimationDelay)) {
            popScaleEffect = 1.0
        }
    }
    
    private func popDown() {
        withAnimation(.easeInOut(duration: popAnimationSpeed)) {
            popScaleEffect = popDownScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: popAnimationSpeed).delay(popAnimationDelay)) {
            popScaleEffect = 1.0
        }
    }

}

struct WorkoutInProgressView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutInProgressView()
            .environmentObject(CompletedWorkoutsViewModel())
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
