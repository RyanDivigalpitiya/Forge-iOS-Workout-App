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
    @State var selectedDetent: PresentationDetent = .medium
    private let availableDetents: [PresentationDetent] = [.medium, .large]
    
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
                        Spacer().frame(height: 100)
                        
                        ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { exerciseIndex in
                            
                            VStack {
                                
                                // EXERCISE NAME + LOG CHANGE BUTTON
                                HStack {
                                    Text(planViewModel.activePlan.exercises[exerciseIndex].name)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .font(.system(size: 30))
                                    Spacer()
                                    #warning ("Implement log change button")
                                    Image(systemName: "plusminus.circle.fill")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(fgColor)
                                        .padding(.top,5)
                                        .padding(.trailing, 8)
                                }
                                
                                // EXERCISE SETS
                                VStack(spacing: 0){
                                    ForEach(planViewModel.activePlan.exercises[exerciseIndex].sets.indices, id: \.self) { setIndex in

                                        HStack(spacing: 0) {
                                            Button(action: {
                                                #warning ("Implement set button")
                                                
                                            }) {
                                                Circle()
                                                    .stroke(lineWidth: 2)
                                                    .frame(width: setButtonSize, height: setButtonSize)
                                                    .foregroundColor(fgColor)
                                                    .padding(.trailing, 16)
                                            }
                                            .padding(.trailing, 3)

                                            SetView(setIndex: setIndex, exerciseIndex: exerciseIndex, uniqueSets: true)
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
                    Spacer().frame(height: 70)
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
                        Text("0% Complete  —  00:00:24")
                            .fontWeight(.bold)
                    }

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
                            .environment(\.colorScheme, .dark)
                    }
                    
                    Spacer()
                    
                    // SAVE BUTTON
                    Button(action: {
                        planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
                        planViewModel.savePlans()
                        
                        let completedWorkout = CompletedWorkout(date: Date(), workout: planViewModel.activePlan)
                        completedWorkoutsViewModel.completedWorkouts.append(completedWorkout)
                        completedWorkoutsViewModel.saveCompletedWorkouts()
                    
                        self.presentationMode.wrappedValue.dismiss()
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
