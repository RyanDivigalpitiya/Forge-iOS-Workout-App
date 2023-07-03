import SwiftUI

struct WorkoutInProgressView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////
    
    
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

    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray: Color = Color(red: 0.25, green: 0.25, blue: 0.25)
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize: CGFloat = 28
    
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
                                                        // present break timer
                                                        if planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex].completed {
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                showBreakTimer = true
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
                                            .sheet(isPresented: $showBreakTimer) {
                                                BreakTimerView()
                                                    .environment(\.colorScheme, .dark)
                                            }


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
                
            }
            
            // Top Toolbar
            VStack {
                VStack {
                    Spacer().frame(height: 55)
                    HStack {
                        Spacer()
                        Text("\(planViewModel.activePlan.name)")
                            .font(.system(size: 30))
                            .fontWeight(.bold)
                            .foregroundColor(fgColor)
                        Spacer()
                    }
                    .padding(.bottom,1)
                    
                    HStack {
                        Spacer()
//                        Image(systemName: "timer.circle.fill")
//                            .foregroundColor(fgColor)
//                            .padding(.leading,30)
//                            .hidden()
                        
                        Text("\(percentCompleted)% Complete  —  00:00:24")
                            .fontWeight(.bold)
                        
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(fgColor)
//                            .padding(.trailing,30)
                        Spacer()
                    }
                    .scaleEffect(popScaleEffect)
                }
                .padding(.bottom, 15)
                .background(BlurView(style: .systemChromeMaterial))
                
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
                    Button(action: {
                        exerciseViewModel.activeExercise = Exercise()
                        exerciseViewModel.activeExerciseMode = "AddMode"
                        self.exerciseEditorIsPresented = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                        Text("Add")
                            .font(.headline)
                    }
                    .foregroundColor(fgColor)
                    .sheet(isPresented: $reorderDeleteViewPresented) {
                        ReorderDeleteView(mode: "ExerciseMode")
                            .environment(\.colorScheme, .dark)
                    }
                    .sheet(isPresented: $exerciseEditorIsPresented) {
                        ExerciseEditorView(selectedDetent: $selectedDetent)
                            .presentationDetents([.medium, .large], selection: $selectedDetent)
                            .presentationDragIndicator(.hidden)
                            .environment(\.colorScheme, .dark)
                    }
                    
                    Spacer()
                    
                    // DONE BUTTON
                    Button(action: {
                        
//                        var completedWorkout = WorkoutPlan(copy: planViewModel.activePlan)
                        // save completed workout to persistant storage
                        let completedWorkout = CompletedWorkout(date: Date(), workout: planViewModel.activePlan)
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
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                        Text("Done")
                            .font(.headline)
                    }
                    .foregroundColor(fgColor)
                    
                    Spacer()
                    
                    // REORDER BUTTON
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
                    .sheet(isPresented: $reorderDeleteViewPresented) {
                        ReorderDeleteView(mode: "ExerciseMode")
                            .environment(\.colorScheme, .dark)
                    }
                    
                    Spacer()
                }
                .frame(height: bottomToolbarHeight)
                .background(BlurView(style: .systemChromeMaterial))
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(.black)
        .onAppear{
            calcPercentCompleted()
        }
    }
}

// % Complete label + animation functions
extension WorkoutInProgressView {
    
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
            print(workoutCompletion)
            print(workoutCompletionInt)
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
