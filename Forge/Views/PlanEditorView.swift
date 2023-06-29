import SwiftUI

struct PlanEditorView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-/////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @FocusState private var isPlanNameFocused: Bool // used to assign focus on plan name textfield on appear
    @State private var exerciseEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height

    
    var body: some View {
        ZStack {
            VStack {
                HStack{
                    Spacer()
                    Text(planViewModel.activePlanMode == "AddMode" ? "Create New Plan" : "Edit Plan")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    Spacer() 
                }
                
                TextField("Plan Name (Ex: Leg Day)", text: $planViewModel.activePlan.name)
                    .padding(.vertical, 20)
                    .focused($isPlanNameFocused)
                    .frame(width: 300)
                    .autocapitalization(.words)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 23))
                
                Text("Exercises:")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(EdgeInsets(top:1, leading: 0, bottom: 15, trailing: 0))
                    .foregroundColor(.gray)
                
                // LIST OF EXERCISES
                ScrollView {
                    LazyVStack {
                        ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { index in
                            
                            // EDIT BUTTON
                            Button(action: {
                                exerciseViewModel.activeExerciseMode = "EditMode"
                                exerciseViewModel.activeExercise = planViewModel.activePlan.exercises[index]
                                exerciseViewModel.activeExerciseIndex = index
                                self.exerciseEditorIsPresented = true
                            }) {
                                VStack() {
                                    HStack {
                                        // Exercise Name
                                        Text(planViewModel.activePlan.exercises[index].name)
                                            .foregroundColor(fgColor)
                                            .fontWeight(.bold)
                                            .font(.system(size: 25))
                                            .padding(.bottom,1)
                                        Spacer()
                                    }
                                    let setRepsString = "( \(planViewModel.activePlan.exercises[index].sets) Sets x \(planViewModel.activePlan.exercises[index].reps) Reps )"
                                    
                                    HStack {
                                        // Exercise Data
                                        Text(planViewModel.isThereNonZeroDecimal(in: planViewModel.activePlan.exercises[index].weight) + " lbs")
                                            .fontWeight(.bold)
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                        Text(setRepsString)
                                            .font(.system(size: 20))
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(15)
                            .background(bgColor)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 25)
                        .padding(.vertical, 8)
                        
                        // ADD EXERCISE BUTTON
                        Button(action: {
                            // bring up Exercise Editor View
                            isPlanNameFocused = false
                            exerciseViewModel.activeExerciseMode = "AddMode"
                            exerciseViewModel.activeExercise = Exercise()
                            self.exerciseEditorIsPresented = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise").fontWeight(.bold)
                            }
                            .foregroundColor(fgColor)
                        }
                        .padding(.top, 10)
                        .sheet(isPresented: $exerciseEditorIsPresented) {
                            ExerciseEditorView()
                                .presentationDetents([.medium, .large])
                                .environment(\.colorScheme, .dark)
                        }
                        
                        Spacer().frame(height: 60)
                    }
                }
                
                Spacer()
            }
            
            
            // BOTTOM TOOLBAR
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // CANCEL BUTTON ////////////////////
                    Button(action: {
                        isPlanNameFocused = false
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                        Text("Cancel")
                            .font(.headline)
                    }
                    .foregroundColor(fgColor)
                    .padding(.bottom, 15)
                    
                    Spacer()
                    
                    // REORDER BUTTON
                    Button(action: {
                        isPlanNameFocused = false
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
                    .padding(.bottom, 15)
                    .sheet(isPresented: $reorderDeleteViewPresented) {
                        ReorderDeleteView(mode: "ExerciseMode")
                            .environment(\.colorScheme, .dark)
                    }
                    
                    Spacer()
                    
                    // SAVE BUTTON ////////////////////
                    Button(action: {
                        isPlanNameFocused = false
                        if planViewModel.activePlanMode == "AddMode" {
                            planViewModel.workoutPlans.append(planViewModel.activePlan)
                            planViewModel.savePlans()
                        } else if planViewModel.activePlanMode == "EditMode" {
                            planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
                            planViewModel.savePlans()
                        }
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                        Text("Save")
                            .font(.headline)
                    }
                    .foregroundColor(fgColor)
                    .padding(.bottom, 15)
                    
                    Spacer()
                }
                .frame(height: bottomToolbarHeight)
                .background(BlurView(style: .systemUltraThinMaterial))
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(.black)
        .onAppear {
            isPlanNameFocused = planViewModel.activePlan.name == ""
        }
    }
}

struct PlanEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PlanEditorView()
            .environmentObject(PlanViewModel(mockPlans: mockWorkouts))
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
