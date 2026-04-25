import SwiftUI
import Combine
import UIKit
import ActivityKit

// Anchor-preference plumbing for the joint-mode avatar gutter lives in
// `WorkoutAvatarGutter.swift`: RestingSet, RowID, RowAnchorKey.

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

    // Joint-mode set / rest row heights. Soft floors so rows stay visually
    // consistent across exercises — actual avatar alignment is now driven
    // by anchor preferences in the per-exercise overlay (no longer requires
    // these to match a parallel gutter VStack).
    let setRowHeight: CGFloat = 38
    let restRowHeight: CGFloat = 62
    // Width reserved on the leading edge of every exercise card's outer
    // HStack for the avatar gutter overlay.
    let gutterWidth: CGFloat = 52

    @State private var isWorkoutDone: Bool = false
    @State private var showCancelConfirmation: Bool = false
    @State private var workoutActivity: Activity<WorkoutActivityAttributes>? = nil
    @State private var breakTimerEndDate: Date? = nil

    // NOTE: Stage 6 of the refactor sprint considered extracting myPosition /
    // restingForSet / recomputeMyPosition / rebroadcastJointStateForPeer /
    // handleSetTap into a `JointModeCoordinator: ObservableObject`. Declined
    // on risk/value grounds: the joint-mode state is tightly coupled to the
    // break-timer coordination logic that must stay here (scroll-view
    // shrink/grow, Live Activity, watch haptics). Moving @State to @Published
    // on a coordinator would also reopen the Stage 6d timing gotcha
    // (CLAUDE.md: "Avatar position must be @State, not derived") without a
    // clean fix. Decomposition made instead: anchor-preference types in
    // WorkoutAvatarGutter.swift + the nested set-tap closure hoisted into
    // handleSetTap / scheduleBreakTimerStart.
    //
    // Avatar position in joint mode. First-class @State, recomputed via
    // recomputeMyPosition() at three events (workout start, set-tap toggle,
    // break-timer dismiss). The recompute uses a single rule — "first
    // incomplete set, with a rest-row adjustment when a break timer is
    // active for the immediately-preceding set" — which handles natural
    // progression, out-of-order completion, and out-of-order un-completion
    // uniformly.
    @State private var myPosition: UserPosition = UserPosition(
        exerciseIndex: 0,
        setIndex: 0,
        isResting: false
    )
    // Tracks WHICH set started the currently-running break timer, so the
    // recompute can place the avatar on that set's rest row instead of on
    // the next incomplete set. Set synchronously on the tap that will start
    // a timer (pre-empting the asyncAfter race), cleared on dismiss/start.
    @State private var restingForSet: RestingSet? = nil
    @State private var showTimerSettings = false
    @State private var selectedBreakDuration: Int = GlobalSettings.shared.breakDuration
    @State private var showConfetti = false

    // Solo → joint share flow state. `inviteFriendSheetActive` presents
    // `WorkoutWithFriendView` so the user sees the feature explainer + Copy /
    // Share buttons before broadcasting. `profilePromptActive` gates the
    // name-entry sheet for users who've never used collab before — without a
    // profile, the joined friend would see a "?" avatar for the host.
    @State private var inviteFriendSheetActive: Bool = false
    @State private var profilePromptActive: Bool = false
    @State private var profileDraftName: String = ""
    
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

                                        // AVATAR GUTTER (joint mode only) — empty placeholder that
                                        // reserves leading space for the overlay below to position
                                        // avatars into. Avatars themselves are drawn by the
                                        // overlayPreferenceValue(RowAnchorKey.self) attached to
                                        // this HStack, anchored to the actual rendered Y of each
                                        // row inside the card. No hardcoded offsets.
                                        if sessionClient.isPaired {
                                            Color.clear.frame(width: gutterWidth)
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
                                                    if sessionClient.isPaired {
                                                        peerCompletionCircle(
                                                            exerciseId: planViewModel.activePlan.exercises[exerciseIndex].id,
                                                            setIndex: setIndex
                                                        )
                                                    }

                                                    // SET BUTTON
                                                    // marks set.completed to TRUE OR FALSE
                                                    Button(action: {
                                                        handleSetTap(exerciseIndex: exerciseIndex, setIndex: setIndex)
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
                                                        appearance: sessionClient.isPaired
                                                            ? .workoutActiveCollab(
                                                                isCompleted: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
                                                            )
                                                            : .workoutActive(
                                                                isCompleted: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
                                                            )
                                                    )
                                                }
                                                .frame(height: setRowHeight)
                                                .anchorPreference(
                                                    key: RowAnchorKey.self,
                                                    value: .bounds
                                                ) { [.setRow(setIndex): $0] }

                                                if setIndex < planViewModel.activePlan.exercises[exerciseIndex].sets.count - 1 {
                                                    restBreakRow()
                                                        .anchorPreference(
                                                            key: RowAnchorKey.self,
                                                            value: .bounds
                                                        ) { [.restRow(setIndex): $0] }
                                                }
                                            }
                                        }

                                    }
                                    .padding(17)
                                    .background(bgColor)
                                    .cornerRadius(settings.cornerRadiusLarge)
                                    }
                                    .overlayPreferenceValue(RowAnchorKey.self) { anchors in
                                        if sessionClient.isPaired {
                                            GeometryReader { proxy in
                                                let sets = planViewModel.activePlan.exercises[exerciseIndex].sets
                                                ForEach(sets.indices, id: \.self) { setIndex in
                                                    if let setAnchor = anchors[.setRow(setIndex)] {
                                                        let bounds = proxy[setAnchor]
                                                        avatarColumn(
                                                            for: UserPosition(
                                                                exerciseIndex: exerciseIndex,
                                                                setIndex: setIndex,
                                                                isResting: false
                                                            )
                                                        )
                                                        .position(x: gutterWidth / 2, y: bounds.midY)
                                                    }
                                                    if setIndex < sets.count - 1,
                                                       let restAnchor = anchors[.restRow(setIndex)] {
                                                        let bounds = proxy[restAnchor]
                                                        avatarColumn(
                                                            for: UserPosition(
                                                                exerciseIndex: exerciseIndex,
                                                                setIndex: setIndex,
                                                                isResting: true
                                                            )
                                                        )
                                                        .position(x: gutterWidth / 2, y: bounds.midY)
                                                    }
                                                }
                                            }
                                            .allowsHitTesting(false)
                                        }
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

                                    // Share button — mid-workout invite. Visible only when
                                    // truly solo (no session exists yet). Once a session
                                    // is live (.connecting / .waitingForPeer / .paired /
                                    // .disconnected / .error), the CollabStatusBanner's
                                    // Re-invite path is the single affordance for sharing
                                    // the URL — this avoids two redundant share buttons
                                    // and keeps the joint workout view clean.
                                    if sessionClient.sessionId == nil {
                                        Button(action: handleShareTap) {
                                            Image(systemName: "person.2.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(settings.fgColor)
                                                .frame(width: 44, height: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .disabled(timerEnabled)
                                        .padding(.trailing, 5)
                                    } else {
                                        // Invisible placeholder mirrors the back chevron's
                                        // 44pt footprint so the plan-name text stays centered.
                                        Color.clear
                                            .frame(width: 44, height: 44)
                                            .padding(.trailing, 5)
                                    }
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
                    withAnimation(.easeInOut(duration: settings.animationStandard)) {
                        shouldShowWorkout = true
                        withAnimation(.easeInOut(duration: settings.animationSlow)) {
                            isWorkoutOpacityFull = true
                            scrollViewScaleEffect = 1.0
                        }
                    }
                    startLiveActivity()
                    healthManager.startWorkoutSession()
                    PhoneSessionManager.shared.sendWorkoutStarted()
                    restingForSet = nil
                    recomputeMyPosition()
                }
            }

            // Always-mounted ConfettiView with internal trigger via
            // `triggered`. Conditional `if showConfetti { ... }` mounting
            // caused iOS-18 specific lag in onAppear → startDate landing
            // near dismiss time → confetti barely playing before cut-off.
            // See ConfettiView.swift comment for the full story.
            ConfettiView(
                colors: [settings.fgColor, .white, .black],
                triggered: showConfetti
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            // Joint-mode connectivity banner. Sits above the main workout
            // chrome (top toolbar + scroll view). Appears only when state
            // is non-healthy; .padding(.top, 60) clears the status bar.
            CollabStatusBanner()
                .padding(.top, 60)
        }
        .disabled(isWorkoutDone)
        .alert(
            sessionClient.sessionId != nil ? "Leave Session?" : "Cancel Workout?",
            isPresented: $showCancelConfirmation
        ) {
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
        .sheet(isPresented: $inviteFriendSheetActive) {
            WorkoutWithFriendView(activeWorkoutPlan: planViewModel.activePlan)
                .environment(\.colorScheme, .dark)
        }
        .sheet(isPresented: $profilePromptActive) {
            profileNamePrompt
                .presentationDetents([.height(260)])
                .environment(\.colorScheme, .dark)
        }
        .onAppear {
            // Broadcast my starting position so the peer's avatar column
            // shows me at the first incomplete set right away.
            if sessionClient.isPaired {
                sessionClient.sendPositionUpdate(myPosition)
            }
        }
        .onChange(of: myPosition) { _, new in
            if sessionClient.isPaired {
                sessionClient.sendPositionUpdate(new)
            }
        }
        .onChange(of: sessionClient.state) { _, new in
            // On every transition INTO .paired (initial pair, peer rejoined
            // after leaving, both phones recovering from a server restart),
            // re-broadcast my joint-mode state. The peer's SessionClient
            // cleared its peerPositions / peerCompletedSets / peerBreakTimer
            // dicts when it reconnected, and the server doesn't persist any
            // of it — so without this, the peer's view of me would stay
            // empty until I happen to do something.
            if case .paired = new {
                rebroadcastJointStateForPeer()
            }
        }
    }

    /// Handles a tap on a set's completion circle. Extracted from the Button
    /// action closure in the view body — the flow is non-trivial:
    ///  1. Predict whether toggling this set to completed will start a break
    ///     timer, and pre-empt `restingForSet` BEFORE the plan mutation so
    ///     the recompute resolves the avatar to the rest row in one step
    ///     (no intermediate "next set" frame — Stage 6d gotcha).
    ///  2. Toggle the set inside a `withAnimation` and broadcast the change.
    ///  3. If the toggle just-completed an incomplete set AND the exercise
    ///     isn't already fully complete, schedule the break-timer start
    ///     animation (1s grace period → scroll view shrinks → timer fades in).
    ///  4. Recompute avatar position + percent + Live Activity at the end.
    private func handleSetTap(exerciseIndex: Int, setIndex: Int) {
        let willComplete = !planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
        if willComplete {
            var simulated = planViewModel.activePlan.exercises[exerciseIndex].sets
            simulated[setIndex].completed = true
            let willStartTimer = !simulated.allSatisfy(\.completed)
            if willStartTimer {
                restingForSet = RestingSet(exercise: exerciseIndex, set: setIndex)
            }
        }

        withAnimation(.easeOut(duration: settings.animationQuick)) {
            planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed.toggle()
            let isNowCompleted = planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed
            if sessionClient.isPaired {
                sessionClient.sendSetCompletion(
                    exerciseId: planViewModel.activePlan.exercises[exerciseIndex].id,
                    setIndex: setIndex,
                    completed: isNowCompleted
                )
            }
            if isNowCompleted {
                popUp()
            } else {
                popDown()
            }

            if !planViewModel.activePlan.exercises[exerciseIndex].completed,
               isNowCompleted {
                scheduleBreakTimerStart(exerciseIndex: exerciseIndex, setIndex: setIndex)
            }

            feedbackGenerator.impactOccurred()
            calcPercentCompleted()
            updateLiveActivity()
            recomputeMyPosition()
        }
    }

    /// Schedules the break-timer start animation after a 1-second grace
    /// period — matches the pre-refactor timing exactly. The `guard
    /// !isWorkoutDone` checks prevent the animation from firing if the
    /// workout was cancelled / finished during the delay.
    private func scheduleBreakTimerStart(exerciseIndex: Int, setIndex: Int) {
        isScrollViewDisabled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard !isWorkoutDone else { return }
            withAnimation(.easeInOut(duration: settings.animationStandard)) {
                scrollViewScaleEffect = 0.95
                scrollViewVisible = false
                topToolBarHeight = screenHeight * 0.8
                topToolBarCornerRadius = 30
                timerEnabled = true
                breakTimerEndDate = Date().addingTimeInterval(TimeInterval(selectedBreakDuration))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard !isWorkoutDone else { return }
                    withAnimation(.easeInOut(duration: settings.animationStandard)) {
                        timerVisible = true
                    }
                }
            }
            updateLiveActivity()
            if let endDate = breakTimerEndDate {
                let nextSetForWatch = findNextIncompleteSet()
                PhoneSessionManager.shared.sendTimerStarted(
                    endDate: endDate,
                    duration: selectedBreakDuration,
                    exerciseName: nextSetForWatch?.exerciseName,
                    setDescription: nextSetForWatch?.setDescription
                )
                if sessionClient.isPaired {
                    sessionClient.sendBreakTimerUpdate(
                        endDate: endDate,
                        exerciseIndex: exerciseIndex,
                        setIndex: setIndex
                    )
                }
            }
        }
    }

    /// Pushes my current avatar position, every completed set, and any
    /// active break timer to the peer. Called on every transition into
    /// .paired so a freshly-(re)paired peer's local view of me is
    /// fully populated without waiting for the next user action.
    private func rebroadcastJointStateForPeer() {
        guard sessionClient.isPaired else { return }

        sessionClient.sendPositionUpdate(myPosition)

        for exercise in planViewModel.activePlan.exercises {
            for (setIndex, set) in exercise.sets.enumerated() where set.completed {
                sessionClient.sendSetCompletion(
                    exerciseId: exercise.id,
                    setIndex: setIndex,
                    completed: true
                )
            }
        }

        if let endDate = breakTimerEndDate, timerEnabled {
            // Use myPosition's setIndex/exerciseIndex if currently resting;
            // fall back to (0, 0) which the receiver ignores when endDate
            // is non-nil only for placement, not for the dict key.
            let exIdx = myPosition.exerciseIndex
            let sIdx = myPosition.setIndex
            sessionClient.sendBreakTimerUpdate(
                endDate: endDate,
                exerciseIndex: exIdx,
                setIndex: sIdx
            )
        }
    }

    /// Entry point for the Share button in the top toolbar. The button is
    /// only visible when `sessionId == nil` (truly solo), so two paths:
    ///   1. Host has never set a profile → present name prompt first; the
    ///      prompt's submit handler re-invokes this method once the profile
    ///      is set, so the friend never sees a "?" avatar for the host.
    ///   2. Otherwise → present `WorkoutWithFriendView` as a sheet. The
    ///      sheet's Copy / Share buttons call `startSharedSessionForActiveWorkout`
    ///      themselves (registering `workoutInProgress` server-side so Stage 7b'
    ///      auto-routes joiners back into this view) and dismiss back here.
    private func handleShareTap() {
        if sessionClient.myProfile == nil {
            profileDraftName = ""
            profilePromptActive = true
            return
        }
        inviteFriendSheetActive = true
    }

    /// Minimal name-entry sheet shown when the user taps Share without ever
    /// having used collab. Photo is skipped here — can be added later via
    /// the normal JoinSessionView flow. On Save we submit the profile and
    /// re-enter handleShareTap() to continue the share flow.
    private var profileNamePrompt: some View {
        VStack(spacing: 20) {
            Text("Your Name")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 30)

            Text("Shown to your friend when they join.")
                .font(.caption)
                .foregroundColor(.gray)

            TextField("", text: $profileDraftName, prompt: Text("Required").foregroundColor(.gray))
                .font(.title3)
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(white: 0.15))
                .cornerRadius(settings.cornerRadiusMedium)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(.horizontal, 24)

            Button {
                let trimmed = profileDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                sessionClient.submitProfile(Profile(name: trimmed, photoData: nil))
                profilePromptActive = false
                // Continue the interrupted share flow now that myProfile is set.
                DispatchQueue.main.async { handleShareTap() }
            } label: {
                Text("Save")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(
                profileDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.gray.opacity(0.3)
                    : settings.fgColor
            )
            .foregroundColor(.white)
            .cornerRadius(settings.cornerRadiusMedium)
            .padding(.horizontal, 24)
            .disabled(profileDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
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

        // In joint mode, fully end the collab session rather than dropping
        // the user back onto PlanSuggestionView — otherwise they could
        // suggest a new plan and re-trigger startWorkout, stomping a state
        // the partner is no longer expecting. The state observer on
        // CompletedWorkoutsView unwinds the NavigationStack to History
        // when state becomes .idle.
        let wasInSession = sessionClient.sessionId != nil
        dismiss()
        completedWorkoutsViewModel.isSelectPlanViewActive = false
        if wasInSession {
            sessionClient.disconnect()
        }
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
                Log.debug("[Forge] endWorkoutSession callback — calories: \(calories as Any)")
                if let lastIndex = completedWorkoutsViewModel.completedWorkouts.indices.last {
                    completedWorkoutsViewModel.completedWorkouts[lastIndex].caloriesBurned = calories
                    completedWorkoutsViewModel.saveCompletedWorkouts()
                }
            }
        } else {
            healthManager.saveWorkout(startDate: startDate, endDate: Date(), elapsedTime: Date().timeIntervalSince(startDate))
        }

        triggerHapticFeedback()
        withAnimation(.easeInOut(duration: settings.animationSlow)) {
            isDoneCheckMarkVisible = true
        }
        withAnimation(.easeInOut(duration: 2.0)) {
            scrollViewScaleEffect = 0.95
            isWorkoutOpacityFull = false
        }
        // Explicitly nil-animation for the confetti flag. Without this,
        // iOS 18 propagates the surrounding 2s easeInOut transaction
        // onto this bare state change, and the conditional view's
        // default .opacity insertion transition fades the confetti in
        // over 2s — peaking just as the dismiss timer fires (so the
        // confetti barely appears before it's cut off). iOS 26 changed
        // transaction propagation, hiding the bug. withAnimation(nil)
        // forces zero-duration insertion regardless of OS version.
        withAnimation(nil) {
            showConfetti = true
        }
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
        Log.debug("[Forge] dismissBreakTimerView called (cancelPendingNotification: \(cancelPendingNotification))")

        // Remove scheduled notification only when the user explicitly dismisses the
        // timer (X button or Done). On natural expiry, the notification has either
        // already fired or is suppressed by AppDelegate's willPresent handler, so
        // cancellation is unnecessary and would race against system delivery.
        if cancelPendingNotification {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [BreakTimerView.notificationIdentifier])
        }

        withAnimation(.easeInOut(duration: settings.animationStandard)) {
            timerVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: settings.animationStandard)) {
                isScrollViewDisabled = false
                scrollViewVisible = true
                if !isWorkoutDone {
                    scrollViewScaleEffect = 1.0
                }
                timerEnabled = false       // removes BreakTimerView from view tree → its onDisappear cancels its timer subscription
                breakTimerEndDate = nil
                topToolBarHeight = 163
                topToolBarCornerRadius = 0
                // Clear the rest-adjustment hint and let recompute resolve
                // the avatar back to the first incomplete set.
                restingForSet = nil
                recomputeMyPosition()
            }
            updateLiveActivity()
            PhoneSessionManager.shared.sendTimerDismissed()
            if sessionClient.isPaired {
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
            Log.debug("[Forge] Failed to start Live Activity: \(error)")
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

    // myPosition is an @State property declared at the top of the struct
    // and assigned by recomputeMyPosition() below.

    /// Single source of truth for avatar position. Applies the unified rule:
    /// position is the first incomplete set, with a rest-row adjustment if
    /// a break timer is active for the set immediately preceding it. Out-
    /// of-order completion / un-completion fall out naturally — there's no
    /// special branching for "natural" vs "skipped" taps.
    private func recomputeMyPosition() {
        let plan = planViewModel.activePlan
        guard !plan.exercises.isEmpty else {
            myPosition = UserPosition(exerciseIndex: 0, setIndex: 0, isResting: false)
            return
        }

        // Find the first incomplete set across all exercises. Zero-set
        // exercises naturally skip because firstIndex on an empty array
        // returns nil — so a corrupt plan can't jam the avatar on a row
        // that doesn't exist.
        var firstIncomplete: (ex: Int, set: Int)? = nil
        for (exIdx, ex) in plan.exercises.enumerated() {
            if let sIdx = ex.sets.firstIndex(where: { !$0.completed }) {
                firstIncomplete = (exIdx, sIdx)
                break
            }
        }

        guard let next = firstIncomplete else {
            // Workout fully complete — park at the final set of the last
            // non-empty exercise. A zero-set trailing exercise would otherwise
            // produce an invalid position (setIndex = 0 with no set there).
            if let lastEx = plan.exercises.indices.reversed().first(where: {
                !plan.exercises[$0].sets.isEmpty
            }) {
                let lastSet = plan.exercises[lastEx].sets.count - 1
                myPosition = UserPosition(exerciseIndex: lastEx, setIndex: lastSet, isResting: false)
            } else {
                myPosition = UserPosition(exerciseIndex: 0, setIndex: 0, isResting: false)
            }
            return
        }

        // Rest adjustment: if the active break timer is for the set right
        // before first-incomplete (in the same exercise), the avatar belongs
        // on that rest row, not on the upcoming set.
        if let resting = restingForSet,
           resting.exercise == next.ex,
           resting.set == next.set - 1 {
            myPosition = UserPosition(
                exerciseIndex: resting.exercise,
                setIndex: resting.set,
                isResting: true
            )
            return
        }

        myPosition = UserPosition(exerciseIndex: next.ex, setIndex: next.set, isResting: false)
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

    /// The horizontal rest-break row that sits between set rows (within an
    /// exercise) and at the bottom of every exercise card except the last
    /// (between exercises). Peer / user connector columns + "Rest (Xs)"
    /// label. Wrapped in a Button so tapping anywhere on the row opens
    /// the break-duration picker — replaces the timer icon that used to
    /// live in the top toolbar.
    @ViewBuilder
    private func restBreakRow() -> some View {
        Button(action: { showTimerSettings = true }) {
            HStack(spacing: 0) {
                if sessionClient.isPaired {
                    restConnectorColumn()
                        .padding(.trailing, 8)
                }
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            .cornerRadius(settings.cornerRadiusSmall)
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
