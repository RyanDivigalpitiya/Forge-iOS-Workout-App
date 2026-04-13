import SwiftUI
import Combine
import UIKit
import ActivityKit

struct WorkoutInProgressView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var healthManager: WorkoutHealthManager
    
    
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    @State var selectedDetent: PresentationDetent = .medium
    @State var percentCompleted: Int = 0

    // Break timer coordination state — BreakTimerView owns its own timer state.
    // The parent retains these to coordinate the scroll-view shrink/grow animation.
    @State private var topToolBarHeight: CGFloat = 163
    @State private var topToolBarCornerRadius: CGFloat = 0
    @State private var timerEnabled = false      // gates whether BreakTimerView is rendered
    @State private var timerVisible = false      // controls BreakTimerView's opacity
    @State private var isScrollViewDisabled = false
    @State private var startDate = Date()
    @State private var elapsedSeconds: Int = 0
    private let stopwatchTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
    @State private var showCancelConfirmation: Bool = false
    @State private var workoutActivity: Activity<WorkoutActivityAttributes>? = nil
    @State private var breakTimerEndDate: Date? = nil
    @State private var showTimerSettings = false
    @State private var selectedBreakDuration: Int = GlobalSettings.shared.breakDuration
    
    var body: some View {
        ZStack {
            // Workout In Progress Content
            if shouldShowWorkout{
                ZStack {
                    // EXERCISE LIST CONTAINER
                    VStack {
                        ScrollView {
                            
                            LazyVStack {
                                Spacer().frame(height: 118)
                                
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
                                                                            breakTimerEndDate = Date().addingTimeInterval(TimeInterval(selectedBreakDuration))
                                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                                withAnimation(.easeInOut(duration: 0.5)) {
                                                                                    timerVisible = true
                                                                                }
                                                                            }
                                                                        }
                                                                        updateLiveActivity()
                                                                    }
                                                                }
                                                            }
                                                            
                                                            feedbackGenerator.impactOccurred()
                                                            calcPercentCompleted()
                                                            updateLiveActivity()
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
                                                        Text("Rest ( \(selectedBreakDuration)s )")
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
                            
                            // Plan name + back button + %complete
                            VStack(spacing:0) {
                                HStack {
                                    Button(action: { showCancelConfirmation = true }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(fgColor)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .disabled(timerEnabled)
                                    .padding(.leading, 5)

                                    Spacer()
                                    Text("\(planViewModel.activePlan.name)")
                                        .font(.system(size: 30))
                                        .fontWeight(.bold)
                                        .foregroundColor(fgColor)
                                    Spacer()

                                    Button(action: { showTimerSettings = true }) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundColor(fgColor)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .disabled(timerEnabled)
                                    .padding(.trailing, 5)
                                }
                                .padding(.bottom,1)

                                Text(formattedElapsedTime)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                    .onReceive(stopwatchTimer) { _ in
                                        if shouldShowWorkout && !isWorkoutDone {
                                            elapsedSeconds = Int(Date().timeIntervalSince(startDate))
                                        }
                                    }

                                HStack(spacing:0) {
                                    Spacer()

                                    Text("\(percentCompleted)% Complete")
                                        .fontWeight(.bold)

                                    Spacer()
                                }
                                .padding(.bottom, 18)
                                .padding(.top,5)
                                .scaleEffect(popScaleEffect)
                            }
                            .frame(height: 163)
                            
                            Spacer()
                            if timerEnabled {
                                BreakTimerView(
                                    durationSeconds: selectedBreakDuration,
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
                    startLiveActivity()
                }
            }
        }
        .disabled(isWorkoutDone)
        .alert("Cancel Workout?", isPresented: $showCancelConfirmation) {
            Button("No", role: .cancel) { }
            Button("Yes", role: .destructive) {
                cancelWorkout()
            }
        }
        .sheet(isPresented: $showTimerSettings) {
            BreakDurationPickerView(
                selectedDuration: $selectedBreakDuration,
                onSave: {
                    GlobalSettings.shared.breakDuration = selectedBreakDuration
                }
            )
            .fixedSize(horizontal: false, vertical: true)
            .presentationDetents([.height(300)])
            .environment(\.colorScheme, .dark)
        }
    }
}

// % Complete label + animation functions
extension WorkoutInProgressView {

    var formattedElapsedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    func cancelWorkout() {
        // stop timers
        dismissBreakTimerView()
        endLiveActivity()
        isWorkoutDone = true

        // Reset set completions (same as finishWorkout)
        for exerciseIndex in planViewModel.activePlan.exercises.indices {
            for setIndex in planViewModel.activePlan.exercises[exerciseIndex].sets.indices {
                planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed = false
            }
            planViewModel.activePlan.exercises[exerciseIndex].completed = false
        }

        // Save plan modifications (added/reordered/logged exercises)
        // but do NOT set lastCompleted and do NOT save a CompletedWorkout.
        if planViewModel.workoutPlans.indices.contains(planViewModel.activePlanIndex) {
            planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
        }
        planViewModel.savePlans()

        // Dismiss back to history
        dismiss()
        completedWorkoutsViewModel.isSelectPlanViewActive = false
    }

    func finishWorkout() {
        // stop timers
        dismissBreakTimerView()
        endLiveActivity()
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

        // Save to Apple Health
        healthManager.saveWorkout(startDate: startDate, endDate: Date(), elapsedTime: Date().timeIntervalSince(startDate))

        triggerHapticFeedback()
        withAnimation(.easeInOut(duration: 1)) {
            isDoneCheckMarkVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Reset set completions and save plan AFTER the dismiss animation,
            // so the user never sees exercises visually unchecking.
            for exerciseIndex in planViewModel.activePlan.exercises.indices {
                for setIndex in planViewModel.activePlan.exercises[exerciseIndex].sets.indices {
                    planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed = false
                }
                planViewModel.activePlan.exercises[exerciseIndex].completed = false
            }

            planViewModel.activePlan.lastCompleted = Date()
            if planViewModel.workoutPlans.indices.contains(planViewModel.activePlanIndex) {
                planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
            }
            planViewModel.savePlans()

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
                breakTimerEndDate = nil
                topToolBarHeight = 163
                topToolBarCornerRadius = 0
            }
            updateLiveActivity()
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

    // MARK: - Live Activity

    private func findNextIncompleteSet() -> (exerciseName: String, setDescription: String)? {
        for exercise in planViewModel.activePlan.exercises {
            for (index, set) in exercise.sets.enumerated() {
                if !set.completed {
                    let setLabel = "Set \(index + 1)"
                    let detail = set.tillFailure
                        ? "Until Failure"
                        : "\(Int(set.weight)) lb x \(set.reps) reps"
                    return (exercise.name, "\(setLabel) · \(detail)")
                }
            }
        }
        return nil
    }

    private func buildContentState() -> WorkoutActivityAttributes.ContentState {
        let nextSet = findNextIncompleteSet()
        return WorkoutActivityAttributes.ContentState(
            percentCompleted: percentCompleted,
            isResting: timerEnabled,
            restEndDate: timerEnabled ? breakTimerEndDate : nil,
            nextExerciseName: nextSet?.exerciseName,
            nextSetDescription: nextSet?.setDescription
        )
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WorkoutActivityAttributes(planName: planViewModel.activePlan.name)
        let state = buildContentState()
        do {
            workoutActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[Forge] Failed to start Live Activity: \(error)")
        }
    }

    func updateLiveActivity() {
        guard let workoutActivity else { return }
        let state = buildContentState()
        Task {
            await workoutActivity.update(.init(state: state, staleDate: nil))
        }
    }

    func endLiveActivity() {
        guard let workoutActivity else { return }
        let state = buildContentState()
        Task {
            await workoutActivity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.workoutActivity = nil
    }

}

struct BreakDurationPickerView: View {
    @Binding var selectedDuration: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editingDuration: Int = 0

    private let fgColor = GlobalSettings.shared.fgColor
    private let buttonCircleBgColor = GlobalSettings.shared.buttonCircleBgColor
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let step = 5
    private let minDuration = 5
    private let maxDuration = 300
    private var durationRange: [Int] { Array(stride(from: maxDuration, through: minDuration, by: -step)) }

    var body: some View {
        VStack {
            // Top toolbar: X button, title, checkmark button
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .frame(width: 28, height: 28)
                            .foregroundColor(buttonCircleBgColor)
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 11, height: 11)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 20)

                Spacer()

                Text("Break Timer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(fgColor)

                Spacer()

                Button(action: {
                    selectedDuration = editingDuration
                    onSave()
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .frame(width: 28, height: 28)
                            .foregroundColor(buttonCircleBgColor)
                        Image("Checkmark")
                            .resizable()
                            .frame(width: 15, height: 13)
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 25)

            Picker(selection: $editingDuration, label: Text("Duration")) {
                ForEach(durationRange, id: \.self) { value in
                    Text("\(value)s")
                        .foregroundColor(fgColor)
                        .tag(value)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(maxHeight: 150)

            HStack {
                Button(action: {
                    if editingDuration > minDuration {
                        editingDuration -= step
                        feedbackGenerator.impactOccurred()
                    }
                }) {
                    Image(systemName: "minus")
                        .foregroundColor(.black)
                        .font(.system(size: 15))
                        .bold()
                        .padding(5)
                }

                Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                Button(action: {
                    if editingDuration < maxDuration {
                        editingDuration += step
                        feedbackGenerator.impactOccurred()
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.black)
                        .font(.system(size: 15))
                        .bold()
                        .padding(5)
                }
            }
            .frame(width: 85, height: 30)
            .background(fgColor)
            .cornerRadius(5)
            .padding(.bottom, 20)
        }
        .onAppear {
            editingDuration = selectedDuration
        }
    }
}

struct WorkoutInProgressView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutInProgressView()
            .environmentObject(CompletedWorkoutsViewModel())
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(ExerciseViewModel())
            .environmentObject(WorkoutHealthManager())
            .preferredColorScheme(.dark)
    }
}
