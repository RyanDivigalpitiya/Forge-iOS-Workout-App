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
    
    // Animation + Feedback parameters
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var popScaleEffect: CGFloat = 1.0
    private var popUpScaleSize: CGFloat = 1.05
    private var popDownScaleSize: CGFloat = 0.95
    let popAnimationSpeed: Double = 0.05
    let popAnimationDelay: Double = 0.05
    @State private var scrollViewScaleEffect: CGFloat = 1.0
    @State private var scrollViewVisible = true

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

    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray: Color = Color(red: 0.25, green: 0.25, blue: 0.25)
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize: CGFloat = 28
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    
    var body: some View {
        ZStack {
            // Exercise List
            VStack {
                ScrollView {
                    
                    LazyVStack {
                        Spacer().frame(height: 85)
                        
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
                                        #warning ("Test log change functionality")
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
                                                SetView(setIndex: setIndex, exerciseIndex: exerciseIndex, uniqueSets: true, displayLabelBKG: planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed ? false : true)
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
                #warning ("Implement toolbar buttons")
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
                                .font(.headline)
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
                            let completedWorkout = CompletedWorkout(date: Date(), workout: planViewModel.activePlan, elapsedTime: stopwatchViewModel.currentTime)
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
                            
                            self.presentationMode.wrappedValue.dismiss()
                            // after dismissing this view, send user back to CompletedWorkoutsView
                            completedWorkoutsViewModel.isSelectPlanViewActive = false
                        }) {
                            HStack {
                                Text("Done")
    //                                .font(.headline)
                                    .font(.system(size: 23))
                                    .bold()
                            }
                            .frame(width: 90, height: 41)
                            .background(fgColor)
                            .foregroundColor(.black)
                            .cornerRadius(500)
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
                                .font(.headline)
                        }
                        .foregroundColor(fgColor)
                        .disabled(timerEnabled)
                        .sheet(isPresented: $reorderDeleteViewPresented) {
                            ReorderDeleteView(mode: "ExerciseMode")
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
        .background(.black)
        .onAppear{
            calcPercentCompleted()
            stopwatchViewModel.startStopWatch()
        }
        .onDisappear {
            stopwatchViewModel.stopStopWatch()
        }

    }
}

// % Complete label + animation functions
extension WorkoutInProgressView {
    
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
