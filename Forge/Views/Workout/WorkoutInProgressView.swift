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
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var sessionClient: SessionClient


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


    @EnvironmentObject var settings: GlobalSettings
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray = GlobalSettings.shared.darkGray
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize = GlobalSettings.shared.setButtonSize
    let setsFontSize = GlobalSettings.shared.setsFontSize
    let setsSpacing = GlobalSettings.shared.setsSpacing
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    // Joint-mode avatar-gutter alignment constants. Applied symmetrically to
    // the inner set/rest rows and the outer avatar column so avatars line up
    // with the rows they represent. Tuned empirically — if SetView or the
    // rest connector grow, bump these.
    let setRowHeight: CGFloat = 38
    let restRowHeight: CGFloat = 62
    let exerciseNameRowOffset: CGFloat = 73

    @State private var isWorkoutDone: Bool = false
    @State private var showCancelConfirmation: Bool = false
    @State private var workoutActivity: Activity<WorkoutActivityAttributes>? = nil
    @State private var breakTimerEndDate: Date? = nil
    @State private var showTimerSettings = false
    @State private var selectedBreakDuration: Int = GlobalSettings.shared.breakDuration
    @State private var showConfetti = false
    
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

                                    HStack(alignment: .top, spacing: 0) {

                                        // AVATAR GUTTER (joint mode only) — parallel VStack that
                                        // mirrors the card's internal set/rest sequence so avatars
                                        // line up with the rows they represent. Lives OUTSIDE the
                                        // card's grey background. Solo-mode layout is unchanged:
                                        // the HStack has a single child (the card) in that path.
                                        if sessionClient.state == .connected {
                                            exerciseAvatarColumn(for: exerciseIndex)
                                                .padding(.top, exerciseNameRowOffset)
                                        }

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
                                                    .foregroundColor(settings.fgColor)
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
                                                    // PEER CHECKBOX (joint mode only) — grey circle
                                                    // filled with a grey checkmark when the peer
                                                    // has completed this set. Non-interactive —
                                                    // just a status mirror.
                                                    if sessionClient.state == .connected {
                                                        peerCompletionCircle(
                                                            exerciseId: planViewModel.activePlan.exercises[exerciseIndex].id,
                                                            setIndex: setIndex
                                                        )
                                                    }

                                                    // SET BUTTON
                                                    // marks set.completed to TRUE OR FALSE
                                                    Button(action: {

                                                        withAnimation(.easeOut(duration: 0.2)) {
                                                            planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed.toggle()
                                                            let isNowCompleted = planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
                                                            if sessionClient.state == .connected {
                                                                sessionClient.sendSetCompletion(
                                                                    exerciseId: planViewModel.activePlan.exercises[exerciseIndex].id,
                                                                    setIndex: setIndex,
                                                                    completed: isNowCompleted
                                                                )
                                                            }
                                                            if planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed {
                                                                popUp()
                                                            } else {
                                                                popDown()
                                                            }
                                                            
                                                            if !planViewModel.activePlan.exercises[exerciseIndex].completed {
                                                                if planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed {
                                                                    isScrollViewDisabled = true
                                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                        guard !isWorkoutDone else { return }
                                                                        withAnimation(.easeInOut(duration: 0.5)) {
                                                                            scrollViewScaleEffect = 0.95
                                                                            scrollViewVisible = false
                                                                            topToolBarHeight = screenHeight*0.8
                                                                            topToolBarCornerRadius = 30
                                                                            timerEnabled = true
                                                                            breakTimerEndDate = Date().addingTimeInterval(TimeInterval(selectedBreakDuration))
                                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                                guard !isWorkoutDone else { return }
                                                                                withAnimation(.easeInOut(duration: 0.5)) {
                                                                                    timerVisible = true
                                                                                }
                                                                            }
                                                                        }
                                                                        updateLiveActivity()
                                                                        let nextSetForWatch = findNextIncompleteSet()
                                                                        PhoneSessionManager.shared.sendTimerStarted(
                                                                            endDate: breakTimerEndDate!,
                                                                            duration: selectedBreakDuration,
                                                                            exerciseName: nextSetForWatch?.exerciseName,
                                                                            setDescription: nextSetForWatch?.setDescription
                                                                        )
                                                                        if sessionClient.state == .connected {
                                                                            sessionClient.sendBreakTimerUpdate(
                                                                                endDate: breakTimerEndDate,
                                                                                exerciseIndex: exerciseIndex,
                                                                                setIndex: setIndex
                                                                            )
                                                                        }
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
                                                                Image(systemName: "checkmark")
                                                                    .resizable()
                                                                    .frame(width: 13, height: 11)
                                                                    .fontWeight(.bold)
                                                                    .foregroundColor(settings.fgColor)
                                                                    .padding(.top,1)
                                                                    .padding(.trailing, 16)
                                                                Circle()
                                                                    .stroke(lineWidth: 2)
                                                                    .frame(width: setButtonSize, height: setButtonSize)
                                                                    .foregroundColor(settings.fgColor)
                                                                    .padding(.trailing, 16)
                                                            }
                                                            .opacity(0.5)
                                                        } else {
                                                            Circle()
                                                                .stroke(lineWidth: 2)
                                                                .frame(width: setButtonSize, height: setButtonSize)
                                                                .foregroundColor(settings.fgColor)
                                                                .padding(.trailing, 16)
                                                        }
                                                
                                                    }
                                                    .padding(.trailing, 3)

                                                    
                                                    SetView(
                                                        content: .individual(
                                                            set: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex],
                                                            index: setIndex
                                                        ),
                                                        appearance: sessionClient.state == .connected
                                                            ? .workoutActiveCollab(
                                                                isCompleted: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
                                                            )
                                                            : .workoutActive(
                                                                isCompleted: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
                                                            )
                                                    )
                                                }
                                                .frame(height: setRowHeight)

                                                if setIndex < planViewModel.activePlan.exercises[exerciseIndex].sets.count - 1 {
                                                    HStack(spacing: 0) {
                                                        // Peer column's rest indicator (joint mode only) — mirrors
                                                        // the trailing-padding on peerCompletionCircle above so it
                                                        // stays aligned with the grey circle column.
                                                        if sessionClient.state == .connected {
                                                            restConnectorColumn()
                                                                .padding(.trailing, 8)
                                                        }
                                                        // User column's rest indicator — matches the trailing-padding
                                                        // on the user's red set button (.padding(.trailing, 16)).
                                                        restConnectorColumn()
                                                            .padding(.trailing, 16)
                                                        Text("Rest ( \(selectedBreakDuration)s )")
                                                            .font(.system(size: 14))
                                                            .fontWeight(.bold)
                                                            .foregroundColor(darkGray)
                                                            .padding(.vertical, 15)
                                                            .padding(.leading, 10)
                                                        Spacer()
                                                    }
                                                    .frame(height: restRowHeight)
                                                }
                                            }
                                        }

                                    }
                                    .padding(17) //.padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
                                    .background(bgColor)
                                    .cornerRadius(16)
                                    }
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
                                            .foregroundColor(settings.fgColor)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .disabled(timerEnabled)
                                    .padding(.leading, 5)

                                    Spacer()
                                    Text("\(planViewModel.activePlan.name)")
                                        .font(.system(size: 30))
                                        .fontWeight(.bold)
                                        .foregroundColor(settings.fgColor)
                                    Spacer()

                                    Button(action: { showTimerSettings = true }) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundColor(settings.fgColor)
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
                                let nextSet = findNextIncompleteSet()
                                BreakTimerView(
                                    durationSeconds: selectedBreakDuration,
                                    timerVisible: $timerVisible,
                                    nextExerciseName: nextSet?.exerciseName,
                                    nextSetDescription: nextSet?.setDescription,
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
                    healthManager.startWorkoutSession()
                    PhoneSessionManager.shared.sendWorkoutStarted()
                }
            }

            if showConfetti {
                ConfettiView(colors: [settings.fgColor, .white, .black])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
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
        .onAppear {
            // Broadcast my starting position so the peer's avatar column
            // shows me at the first incomplete set right away.
            if sessionClient.state == .connected {
                sessionClient.sendPositionUpdate(myPosition)
            }
        }
        .onChange(of: myPosition) { _, new in
            if sessionClient.state == .connected {
                sessionClient.sendPositionUpdate(new)
            }
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
        PhoneSessionManager.shared.sendWorkoutEnded()
        healthManager.endWorkoutSession()
        isWorkoutDone = true

        // Reset ready flag so the next workout-start round-trip works with a
        // single tap per phone. Without this, server-side isReady stays true,
        // one tap toggles to false, and re-entering requires two taps each.
        sessionClient.setReady(false)

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
        PhoneSessionManager.shared.sendWorkoutEnded()
        isWorkoutDone = true

        // Reset ready flag (see cancelWorkout for rationale).
        sessionClient.setReady(false)

        // save completed workout to persistant storage
        let completedWorkout = CompletedWorkout(
            date: Date(),
            workout: planViewModel.activePlan,
            elapsedTime: Date().timeIntervalSince(startDate),
            completion: "\(percentCompleted)%"
        )
        completedWorkoutsViewModel.completedWorkouts.append(completedWorkout)
        completedWorkoutsViewModel.saveCompletedWorkouts()

        // Save to Apple Health — live session saves automatically via its builder;
        // fall back to manual save if no session was started (e.g. HealthKit denied).
        // When the live session finishes, patch calories into the just-saved workout.
        if healthManager.hasActiveSession {
            healthManager.endWorkoutSession { calories in
                print("[Forge] endWorkoutSession callback — calories: \(calories as Any)")
                if let lastIndex = completedWorkoutsViewModel.completedWorkouts.indices.last {
                    completedWorkoutsViewModel.completedWorkouts[lastIndex].caloriesBurned = calories
                    completedWorkoutsViewModel.saveCompletedWorkouts()
                }
            }
        } else {
            healthManager.saveWorkout(startDate: startDate, endDate: Date(), elapsedTime: Date().timeIntervalSince(startDate))
        }

        triggerHapticFeedback()
        withAnimation(.easeInOut(duration: 1)) {
            isDoneCheckMarkVisible = true
        }
        withAnimation(.easeInOut(duration: 2.0)) {
            scrollViewScaleEffect = 0.95
            isWorkoutOpacityFull = false
        }
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
                if !isWorkoutDone {
                    scrollViewScaleEffect = 1.0
                }
                timerEnabled = false       // removes BreakTimerView from view tree → its onDisappear cancels its timer subscription
                breakTimerEndDate = nil
                topToolBarHeight = 163
                topToolBarCornerRadius = 0
            }
            updateLiveActivity()
            PhoneSessionManager.shared.sendTimerDismissed()
            if sessionClient.state == .connected {
                // Indices are ignored by the receiver when endDate is nil —
                // they just clear the peer's entry from peerBreakTimer.
                sessionClient.sendBreakTimerUpdate(
                    endDate: nil,
                    exerciseIndex: 0,
                    setIndex: 0
                )
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

    // MARK: - Live Activity

    private func findNextIncompleteSet() -> (exerciseName: String, setDescription: String)? {
        for exercise in planViewModel.activePlan.exercises {
            for (index, set) in exercise.sets.enumerated() {
                if !set.completed {
                    let setLabel = "Set \(index + 1)"
                    let detail = set.tillFailure
                        ? "Until Failure"
                        : "\(Int(set.weight)) lb x \(set.reps) rep\(set.reps == 1 ? "" : "s")"
                    return (exercise.name, "\(setLabel)  →  \(detail)")
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

    // MARK: - Joint workout (Stage 6a + 6b)

    /// Where I currently am in the workout. Derived from set-completion
    /// state + the break timer flags, so the broadcast stays in sync with
    /// UI without needing separate event plumbing. Ties via .onChange to
    /// sessionClient.sendPositionUpdate(_:).
    var myPosition: UserPosition {
        let plan = planViewModel.activePlan
        var firstIncomplete: (ex: Int, set: Int)? = nil
        for (exIdx, ex) in plan.exercises.enumerated() {
            if let sIdx = ex.sets.firstIndex(where: { !$0.completed }) {
                firstIncomplete = (exIdx, sIdx)
                break
            }
        }
        guard let next = firstIncomplete else {
            // All done — park at the last set.
            let lastEx = max(0, plan.exercises.count - 1)
            let lastSet = max(0, (plan.exercises.last?.sets.count ?? 1) - 1)
            return UserPosition(exerciseIndex: lastEx, setIndex: lastSet, isResting: false)
        }
        let resting = timerEnabled && breakTimerEndDate != nil
        if resting, next.set > 0 {
            // Resting within the same exercise — sit on the rest-break row
            // for the just-completed set.
            return UserPosition(exerciseIndex: next.ex, setIndex: next.set - 1, isResting: true)
        }
        // Either not resting, or resting between exercises (there's no
        // explicit between-exercise rest row in the layout, so we move the
        // avatar forward to the incoming exercise's first set).
        return UserPosition(exerciseIndex: next.ex, setIndex: next.set, isResting: false)
    }

    /// Renders the leftmost avatar column for a given row (either a set row
    /// or a rest-break row). Shows any participants whose current position
    /// matches, each with a right-arrow affordance. Fixed-width frame so
    /// rows stay aligned whether or not an avatar lives here this frame.
    @ViewBuilder
    private func avatarColumn(for position: UserPosition) -> some View {
        let showMe = myPosition == position
        let peerIdsHere = sessionClient.peerPositions
            .filter { $0.value == position }
            .map { $0.key }
        let totalHere = (showMe ? 1 : 0) + peerIdsHere.count
        let anyoneHere = totalHere > 0
        // Single avatar sits a bit larger; when two stack, shrink them back
        // to the compact size so the overlap still reads cleanly.
        let avatarDiameter: CGFloat = totalHere >= 2 ? 22 : 28

        HStack(spacing: 0) {
            // Cluster zone — fixed width matching the widest possible cluster
            // (two overlapped 22pt avatars = 34pt). Cluster is right-aligned
            // inside the zone so its right edge stays at a constant x position
            // regardless of how many avatars are present. Peers render first
            // (leftmost, behind); user renders last (on top, to the right).
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: -10) {
                    ForEach(peerIdsHere, id: \.self) { peerId in
                        let profile = sessionClient.peerProfiles[peerId]
                        avatar(
                            data: profile?.photoData,
                            fallbackInitial: initial(from: profile?.name ?? "?"),
                            diameter: avatarDiameter,
                            borderColor: .black,
                            borderWidth: 2
                        )
                    }
                    if showMe {
                        avatar(
                            data: sessionClient.myProfile?.photoData,
                            fallbackInitial: initial(from: sessionClient.myProfile?.name ?? "?"),
                            diameter: avatarDiameter,
                            borderColor: .black,
                            borderWidth: 2
                        )
                    }
                }
            }
            .frame(width: 34)

            // Triangle — always rendered (opacity 0 when nobody's here) so the
            // gutter's intrinsic width stays constant across every row. The
            // symmetric 4pt horizontal paddings make the avatar↔triangle gap
            // and the triangle↔card gap identical.
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
                .opacity(anyoneHere ? 1 : 0)
                .padding(.leading, 4)
                .padding(.trailing, 4)
        }
    }

    /// Renders the external gutter column of avatars for one exercise card.
    /// Mirrors the card's internal set/rest sequence one cell at a time,
    /// with each cell sized to match the corresponding inner row (setRowHeight
    /// or restRowHeight) so avatars stay aligned with the rows inside the
    /// card. Reuses `avatarColumn(for:)` per cell.
    @ViewBuilder
    private func exerciseAvatarColumn(for exerciseIndex: Int) -> some View {
        let sets = planViewModel.activePlan.exercises[exerciseIndex].sets
        VStack(spacing: 0) {
            ForEach(sets.indices, id: \.self) { setIndex in
                avatarColumn(
                    for: UserPosition(
                        exerciseIndex: exerciseIndex,
                        setIndex: setIndex,
                        isResting: false
                    )
                )
                .frame(height: setRowHeight)

                if setIndex < sets.count - 1 {
                    avatarColumn(
                        for: UserPosition(
                            exerciseIndex: exerciseIndex,
                            setIndex: setIndex,
                            isResting: true
                        )
                    )
                    .frame(height: restRowHeight)
                }
            }
        }
    }

    /// The line-dot-line connector rendered between successive set rows as a
    /// visual marker for the rest break. Extracted into a helper because
    /// joint mode needs one under the peer column and one under the user
    /// column (before Stage 6a there was only one, aligned to the single
    /// set-button column).
    private func restConnectorColumn() -> some View {
        VStack(spacing: 0) {
            Rectangle().frame(width: 1, height: 12).foregroundColor(darkGray)
            Circle().frame(width: 6, height: 6).foregroundColor(darkGray).padding(.vertical, 8)
            Rectangle().frame(width: 1, height: 12).foregroundColor(darkGray)
        }
        .frame(width: setButtonSize)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func peerCompletionCircle(exerciseId: UUID, setIndex: Int) -> some View {
        let completed = sessionClient.peerCompletedSets.contains(
            PeerSetKey(exerciseId: exerciseId, setIndex: setIndex)
        )
        if completed {
            ZStack {
                Image(systemName: "checkmark")
                    .resizable()
                    .frame(width: 13, height: 11)
                    .fontWeight(.bold)
                    .foregroundColor(Color.gray)
                    .padding(.top, 1)
                    .padding(.trailing, 8)
                Circle()
                    .stroke(lineWidth: 2)
                    .frame(width: setButtonSize, height: setButtonSize)
                    .foregroundColor(Color.gray)
                    .padding(.trailing, 8)
            }
            .opacity(0.5)
        } else {
            Circle()
                .stroke(lineWidth: 2)
                .frame(width: setButtonSize, height: setButtonSize)
                .foregroundColor(Color.gray)
                .padding(.trailing, 8)
        }
    }

}

struct BreakDurationPickerView: View {
    @Binding var selectedDuration: Int
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editingDuration: Int = 0

    @EnvironmentObject var settings: GlobalSettings
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
                    .foregroundColor(settings.fgColor)

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
                        Image(systemName: "checkmark")
                            .resizable()
                            .frame(width: 15, height: 13)
                            .fontWeight(.bold)
                            .foregroundColor(settings.fgColor)
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 25)

            Picker(selection: $editingDuration, label: Text("Duration")) {
                ForEach(durationRange, id: \.self) { value in
                    Text("\(value)s")
                        .foregroundColor(settings.fgColor)
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
            .background(settings.fgColor)
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
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
