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
    let setsFontSize = GlobalSettings.shared.setsFontSize // Font size used for text in set rows
    let setsSpacing: CGFloat = 5

    
    var body: some View {
        ZStack {
            VStack {
                HStack{
                    Spacer()
                    Text(planViewModel.activePlanMode == "AddMode" ? "Create New Plan" : "Edit Plan")
                        .font(.system(size: 35))
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    Spacer() 
                }
                
                TextField("Plan Name (Ex: Leg Day)", text: $planViewModel.activePlan.name)
                    .padding(.vertical, 15)
                    .focused($isPlanNameFocused)
                    .frame(width: 300)
                    .autocapitalization(.words)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 25))
                
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
                                VStack{
                                    HStack {
                                        Text(planViewModel.activePlan.exercises[index].name)
                                            .fontWeight(.bold)
                                            .foregroundColor(fgColor)
                                            .font(.system(size: setsFontSize))
                                        Spacer()
                                        Image(systemName: "pencil.circle.fill")
                                            .resizable()
                                            .frame(width: 19, height: 19)
                                            .foregroundColor(.gray)
                                            .opacity(0.6)
                                    }
                                    if planViewModel.activePlan.exercises[index].areSetsUnique { // display each unqiue set
                                        VStack{
                                            ForEach(planViewModel.activePlan.exercises[index].sets.indices, id: \.self) { setIndex in
                                                let set = planViewModel.activePlan.exercises[index].sets[setIndex]
                                                HStack {
                                                    Text("Set \(setIndex)")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(.white)
                                                        .frame(width: 58, height: 28)
                                                        .background(fgColor)
                                                        .cornerRadius(5)
                                                        .padding(.trailing, setsSpacing+2)
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
                                                .padding(.vertical,9)
                                                
                                            }
                                        }
                                    } else { // display 1 row: weight x reps x sets
                                        
                                    }
                                }
                            }
                            .padding(15)
                            .background(bgColor)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 15)
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
//                            ExerciseEditorView()
//                                .presentationDetents([.medium, .large])
//                                .environment(\.colorScheme, .dark)
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
//                        ReorderDeleteView(mode: "ExerciseMode")
//                            .environment(\.colorScheme, .dark)
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
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
