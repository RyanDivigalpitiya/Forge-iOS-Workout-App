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
    @EnvironmentObject var stopwatchViewModel: StopwatchViewModel
    
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var exerciseEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    @State private var showBreakTimer = false
    @State var selectedDetent: PresentationDetent = .medium
    @State var percentCompleted: Int = 0
    private let availableDetents: [PresentationDetent] = [.medium, .large]

    // break timer properties
    let timer = Timer.publish(every: 1, on: .main, in: .common)
    private var breakDuration = 60
    @State private var topToolBarHeight: CGFloat = 140
    @State private var topToolBarCornerRadius: CGFloat = 0
    @State private var timerEnabled = false
    @State private var timerVisible = false
    @State private var isScrollViewDisabled = false
    @State private var remainingTime: Int = 60
    @State private var timerSubscription: Cancellable? = nil
    @State private var totalTime: Int = 60
    @State private var appState: UIApplication.State = UIApplication.shared.applicationState
    @State private var startDate = Date()

    // Starting Workout Timer properties
    private var workoutStartingTime = 3 // 3 second workoutStartingtimer
    let workoutStartingtimer = Timer.publish(every: 1, on: .main, in: .common)
    @State private var workoutStartingTimerRemainingTime: Int = 3
    @State private var workoutStartingTimerSubscription: Cancellable? = nil
    @State private var workoutStartingTimerTotalTime: Int = 3
    @State private var workoutTimerContentViewOpacity: Double = 0.0

    // Animation + Feedback parameters
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var popScaleEffect: CGFloat = 1.0
    private var popUpScaleSize: CGFloat = 1.05
    private var popDownScaleSize: CGFloat = 0.95
    let popAnimationSpeed: Double = 0.05
    let popAnimationDelay: Double = 0.05
    @State private var isDoneCheckMarkVisible: Bool = false
    @State private var scrollViewVisible = true
    // Starting timer animation parameters
    @State var isStartingTimerDone: Bool = false
    @State var shouldShowWorkout: Bool = false
    @State var isWorkoutOpacityFull: Bool = false
    @State var scrollViewScaleEffect: CGFloat = 0.95


    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray: Color = Color(red: 0.25, green: 0.25, blue: 0.25)
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize: CGFloat = 28
    let setsFontSize: CGFloat = 20 // Font size used for text in set rows
    let setsSpacing: CGFloat = 3
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    
    var body: some View {
        ZStack {
            // Workout In Progress Content
            if shouldShowWorkout{
                ZStack {
                    // Exercise List
                    VStack {
                        ScrollView {
                            
                            LazyVStack {
                                Spacer().frame(height: 95)
                                
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
                                                exerciseViewModel.activeExerciseMode = "LogMode"
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

                                                    
                                                    ZStack {
                                                       let set = planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex]
                                                        
                                                        HStack {
                                                            if setIndex+1 > 9 {
                                                                Text("Set \(setIndex+1)")
                                                                    .font(.system(size: 16))
                                                                    .foregroundColor(.white)
                                                                    .frame(width: 67, height: 28)
                                                                    .background(set.completed ? Color.clear : fgColor)
                                                                    .cornerRadius(5)
                                                                    .padding(.trailing, setsSpacing+2)
                                                            } else {
                                                                Text("Set \(setIndex+1)")
                                                                    .font(.system(size: 16))
                                                                    .foregroundColor(.white)
                                                                    .frame(width: 58, height: 28)
                                                                    .background(set.completed ? Color.clear : fgColor)
                                                                    .cornerRadius(5)
                                                                    .padding(.trailing, setsSpacing+2)

                                                            }
                                                            Text("\(Int(set.weight)) lb")
                                                                .foregroundColor(.white)
                                                                .padding(.trailing, setsSpacing)
                                                            Image(systemName: "xmark")
                                                                .resizable()
                                                                .frame(width: 10, height: 10)
                                                                .padding(.top,3)
                                                                .foregroundColor(.gray)
                                                                .opacity(0.6)
                                                                .padding(.trailing, setsSpacing)
                                                                
                                                            if set.tillFailure {
                                                                Text("Until Failure").foregroundColor(.gray).opacity(0.6)
                                                            } else {
                                                                Text("\(set.reps) reps").foregroundColor(.gray).opacity(0.6)
                                                            }
                                                            Spacer()
                                                        }
                                                        .fontWeight(.bold)
                                                        .font(.system(size: setsFontSize))
                                                        .opacity(planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed ? 0.5 : 1)
                                                        
                                                        
                                                        
                                                        
                                                        HStack {
                                                            Rectangle()
                                                                .frame(width: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed ? .infinity : 0, height:2)
                                                                .opacity(planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed ? 1 : 0)
                                                            Spacer()
                                                        }
                                                        .offset(x: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed ? -10 : -20,y:0)
                                                    }
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
                                    
                                    Text("\(percentCompleted)% Complete  —  \(stopwatchViewModel.stopwatchText)")
                                        .fontWeight(.bold)
            //                            .font(Font.system(size: 15, design: .monospaced))
                                    Button( action: {
                                        stopwatchViewModel.startStopTapped()
                                    }) {
                                        HStack {
                                            if stopwatchViewModel.isPaused {
                                                Image(systemName: "play.circle.fill")
                                            } else {
                                                Image(systemName: "pause.circle.fill")
                                            }
                                        }
                                        .foregroundColor(fgColor)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 10)
                                    }

                                    Spacer()
                                }
                                .padding(.bottom, 10)
                                .padding(.top,5)
                                .scaleEffect(popScaleEffect)
                            }
                            .frame(height: 130)
                            
                            Spacer()
                            if timerEnabled {
                                
                                // BREAK TIMER
                                VStack(spacing: 0) {
                                    Spacer()
                                    HStack{
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
                                            .foregroundColor(GlobalSettings.shared.fgColor)
                                            .rotationEffect(Angle(degrees: -90))
                                            .animation(.linear(duration: 1), value: remainingTime)
                                        Text("\(remainingTime) s")
                                            .font(.system(size: 60))
                                            .foregroundColor(GlobalSettings.shared.fgColor)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.vertical, 50)
                                    .onReceive(timer) { _ in
                                        if remainingTime > 0 {
                                            remainingTime -= 1
                                        } else {
                                            triggerHapticFeedback()
                                            // shrink the view
                                            dismissBreakTimerView()
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

                                        dismissBreakTimerView()
                                        
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

        //                                Text("Cancel")
        //                                    .font(.system(size: 15))
        //                                    .fontWeight(.heavy)
        //                                    .padding([.leading, .trailing], 15)
        //                                    .padding([.top, .bottom], 7)
        //                                    .background(fgColor)
        //                                    .foregroundColor(.white)
        //                                    .cornerRadius(1000)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 40)
                                .padding(.bottom, 20)
                                .opacity(timerVisible ? 1 : 0)
                                
                                
                            }
                        }
                        .frame(height: topToolBarHeight)
        //                .padding(.bottom, 15)
                        .background(BlurView(style: .systemChromeMaterial))
                        .cornerRadius(topToolBarCornerRadius)
                        
                        Spacer()
                    }
                    .edgesIgnoringSafeArea(.top)
                    
                    // Bottom Toolbar
                    VStack {
                        Spacer()
                        HStack {
                            
                            Spacer()
                            
                            // ADD BUTTON
                            HStack {
                                Button(action: {
                                exerciseViewModel.activeExercise = Exercise()
                                exerciseViewModel.activeExerciseMode = "AddMode"
                                self.exerciseEditorIsPresented = true
                                }) {
                                    Text("Add")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                    Image(systemName: "plus.circle.fill")
                                        .resizable()
                                        .frame(width: 15, height: 15)
                                        .padding(.trailing, 3)
                                }
                                .foregroundColor(fgColor)
                                .disabled(timerEnabled)
                                .sheet(isPresented: $exerciseEditorIsPresented) {
                                    ExerciseEditorView(selectedDetent: $selectedDetent)
                                        .presentationDetents([.medium, .large], selection: $selectedDetent)
                                        .presentationDragIndicator(.hidden)
                                        .environment(\.colorScheme, .dark)
                                }
                            }
                            .frame(width: 0.33*screenWidth)
                            
                            
                            // DONE BUTTON
                            HStack {
                                Button(action: {
                                    dismissBreakTimerView()
                                    
            //                        var completedWorkout = WorkoutPlan(copy: planViewModel.activePlan)
                                    // save completed workout to persistant storage
                                    let completedWorkout = CompletedWorkout(
                                                            date: Date(),
                                                            workout: planViewModel.activePlan,
                                                            elapsedTime: stopwatchViewModel.currentTime,
                                                            completion: "\(percentCompleted)%"
                                    )
                                    completedWorkoutsViewModel.completedWorkouts.append(completedWorkout)
                                    completedWorkoutsViewModel.saveCompletedWorkouts()

                                    // update workout plans with any changes made to active workout plan during workout in progress (ie. log changes + added/re-ordered exercises)
                                    // (first, reset set completions)
                                    
                                    for exerciseIndex in 0...planViewModel.activePlan.exercises.count-1 {
                                        for setIndex in 0...planViewModel.activePlan.exercises[exerciseIndex].sets.count-1 {
                                            planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed = false
                                        }
                                        planViewModel.activePlan.exercises[exerciseIndex].completed = false
                                    }
                                    
                                    // save workout plan to persistant storage
                                    planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
                                    planViewModel.savePlans()
                                    
                                    triggerHapticFeedback()
                                    withAnimation(.easeInOut(duration: 1)) {
                                        isDoneCheckMarkVisible = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        self.presentationMode.wrappedValue.dismiss()
                                        // after dismissing this view, send user back to CompletedWorkoutsView
                                        completedWorkoutsViewModel.isSelectPlanViewActive = false
                                        // reset the starting countdown timer
                                    }
                                    
                                    
                                }) {
                                    ZStack{
                                        HStack {
                                            Text("Done")
                                                .font(.system(size: 20))
                                                .bold()
                                        }
                                        .frame(width: 75, height: 35)
                                        .background(fgColor)
                                        .foregroundColor(.black)
                                        .cornerRadius(500)
                                        .opacity(isDoneCheckMarkVisible ? 0 : 1)
                                        
                                        HStack {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 20))
                                                .bold()
                                        }
                                        .frame(width: 75, height: 35)
                                        .background(fgColor)
                                        .foregroundColor(.black)
                                        .cornerRadius(500)
                                        .opacity(isDoneCheckMarkVisible ? 1 : 0)
                                    }
                                    
                                }
                                .foregroundColor(fgColor)
                            }
                            .frame(width: 0.2*screenWidth)

                            
                            // REORDER BUTTON
                            HStack {
                                Button(action: {
                                    reorderDeleteViewPresented = true
                                }) {
                                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                                        .resizable()
                                        .frame(width: 15, height: 15)
                                        .padding(.trailing, 3)
                                    Text("Edit")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(fgColor)
                                .disabled(timerEnabled)
                                .sheet(isPresented: $reorderDeleteViewPresented) {
                                    ReorderDeleteView(mode: "ExerciseMode")
                                        .presentationDetents([.medium, .large])
                                        .environment(\.colorScheme, .dark)
                                }
                            }
                            .frame(width: 0.33*screenWidth)

                            Spacer()
                        }
                        .padding(.bottom, 15)
                        .frame(height: bottomToolbarHeight)
                        .background(BlurView(style: .systemChromeMaterial))
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
                .opacity(isWorkoutOpacityFull ? 1 : 0)
                .background(.black)
                .onAppear{
                    calcPercentCompleted()
                    stopwatchViewModel.startStopWatch()
                }
                .onDisappear {
                    stopwatchViewModel.stopStopWatch()
                }
            }
            
            if !shouldShowWorkout {
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Starting in ...")
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(GlobalSettings.shared.fgColor)
                            .opacity(workoutTimerContentViewOpacity)
                        Spacer()
                    }
                    Button(action: {
                        workoutStartingTimerRemainingTime = 0
                    }) {
                        ZStack {
                            Circle()
                                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .foregroundColor(Color(.systemGray5))
                            Circle()
                                .trim(from: 0, to: CGFloat(workoutStartingTimerRemainingTime) / CGFloat(workoutStartingTimerTotalTime))
                                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .foregroundColor(GlobalSettings.shared.fgColor)
                                .rotationEffect(Angle(degrees: -90))
                                .animation(.easeOut(duration: 1), value: workoutStartingTimerRemainingTime)
                            Text("\(workoutStartingTimerRemainingTime)")
                                .font(.system(size: 60))
                                .foregroundColor(GlobalSettings.shared.fgColor)
                                .fontWeight(.bold)
                        }
                        .opacity(workoutTimerContentViewOpacity)
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.5)) {
                                workoutTimerContentViewOpacity = 1.0
                            }
                            self.startTimer()

                        }
                        .padding(.vertical, 50)
                        .onReceive(workoutStartingtimer) { _ in
                            if workoutStartingTimerRemainingTime > 0 {
                                workoutStartingTimerRemainingTime -= 1
                                if workoutStartingTimerRemainingTime == 0 {
                                    triggerHapticFeedback()
        //                            print("reached here.")
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        isStartingTimerDone = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            shouldShowWorkout = true
                                        }
                                    }
                                }
                            } else {
                                triggerHapticFeedback()
        //                        print("reached here.")
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isStartingTimerDone = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        shouldShowWorkout = true
                                    }
                                }
                            }
                        }
                        .onAppear {
                            workoutStartingTimerTotalTime = workoutStartingTimerRemainingTime
                        }
                        .onDisappear {
                            workoutStartingTimerSubscription?.cancel()
                        }

                    }

                    Spacer()
                }
                .padding(.horizontal, 40)
                .background(.black)
                .opacity(isStartingTimerDone ? 0 : 1)
            }
        }
    }
}

// % Complete label + animation functions
extension WorkoutInProgressView {
    
    func startTimer() {
        workoutStartingTimerSubscription = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { _ in
            if workoutStartingTimerRemainingTime > 0 {
                workoutStartingTimerRemainingTime -= 1
            } else {
//                triggerHapticFeedback()
//                print("reached here.")
                withAnimation(.easeInOut(duration: 0.5)) {
                    isStartingTimerDone = true
                    shouldShowWorkout = true
                    withAnimation(.easeInOut(duration: 1)) {
                        isWorkoutOpacityFull = true
                        scrollViewScaleEffect = 1.0
                    }
                }
                workoutStartingTimerSubscription?.cancel()
                triggerHapticFeedback()
            }
        }
    }

    
    func dismissBreakTimerView() {
        // Cancel timer subscription
        timerSubscription?.cancel()

        // Remove scheduled notification
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.filter { $0.content.categoryIdentifier == "workoutCategory" }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }

        
        withAnimation(.easeInOut(duration: 0.5)) {
            timerVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isScrollViewDisabled = false
                scrollViewVisible = true
                scrollViewScaleEffect = 1.0
                timerEnabled = false
                topToolBarHeight = 140
                topToolBarCornerRadius = 0
                remainingTime = 60
            }
        }
    }
    
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
            .environmentObject(StopwatchViewModel())
            .preferredColorScheme(.dark)
    }
}
