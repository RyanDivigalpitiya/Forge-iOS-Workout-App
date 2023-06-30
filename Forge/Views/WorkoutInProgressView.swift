import SwiftUI

struct WorkoutInProgressView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var viewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var exerciseEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    
    var body: some View {
        ZStack {
            // Exercise List
            VStack {
                ScrollView {
                    
                    LazyVStack {
                        Spacer().frame(height: 100)
                        ForEach(viewModel.activePlan.exercises.indices, id: \.self) { index in
                            VStack (alignment: .leading) {
//                                HStack {
//                                    Text(viewModel.activePlan.exercises[index].name)
//                                        .font(.system(size: 23))
//                                        .fontWeight(.bold)
//                                        .foregroundColor(.white)
//                                        .padding(.bottom, 5)
//
//                                    Spacer()
//
//                                    // EDIT BUTTON
//                                    Button( action: {
//                                        exerciseViewModel.activeExerciseMode = "EditMode"
//                                        exerciseViewModel.activeExercise = viewModel.activePlan.exercises[index]
//                                        exerciseViewModel.activeExerciseIndex = index
//                                        self.exerciseEditorIsPresented = true
//                                    }) {
//                                        Image(systemName: "plusminus.circle.fill")
//                                            .resizable()
//                                            .frame(width: 20, height: 20)
//                                            .padding(.trailing, 5)
//                                            .foregroundColor(fgColor)
//                                    }
//                                    .sheet(isPresented: $exerciseEditorIsPresented) {
//                                        ExerciseEditorView()
//                                            .presentationDetents([.medium, .large])
//                                            .environment(\.colorScheme, .dark)
//                                    }
//                                }
//                                Text("\(viewModel.activePlan.exercises[index].sets) sets")
//                                    .fontWeight(.bold)
//                                    .font(.system(size: 23))
//                                    .padding(.bottom, 5)
//                                HStack {
//                                    Text("\(Int(viewModel.activePlan.exercises[index].weight)) lbs x \(viewModel.activePlan.exercises[index].reps) reps")
//                                        .fontWeight(.bold)
//                                        .font(.system(size: 23))
//
//                                    Spacer()
//                                }
                                
                            }
                            .padding(15)
                            .foregroundColor(fgColor)
                        }
                        .background(bgColor)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.vertical, 7)
                        
                        Spacer().frame(height: 80)
                    }
                }
                
            }
            
            // Top Toolbar
            VStack {
                VStack {
                    Spacer().frame(height: 80)
                    HStack {
                        Spacer()
                        Text("\(viewModel.activePlan.name)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(fgColor)
                        Spacer()
                    }
                    .padding(.bottom, 20)

                }
                .background(BlurView(style: .systemChromeMaterial))
                
                Spacer()
            }
            .edgesIgnoringSafeArea(.top)
            
            // Bottom Toolbar
            VStack {
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
                        ExerciseEditorView()
                            .presentationDetents([.medium, .large])
                            .environment(\.colorScheme, .dark)
                    }
                    
                    Spacer()
                    
                    // SAVE BUTTON
                    Button(action: {
                        viewModel.workoutPlans[viewModel.activePlanIndex] = viewModel.activePlan
                        viewModel.savePlans()
                        
                        let completedWorkout = CompletedWorkout(date: Date(), workout: viewModel.activePlan)
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
