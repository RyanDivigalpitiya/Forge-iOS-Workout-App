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
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        ZStack {
            // LIST
            VStack {
                ScrollView {
                    LazyVStack {
                        Spacer().frame(height: 180)
                        ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { index in
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
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray5)))
                        }
                        .padding(.horizontal, 25)
                        .padding(.vertical, 8)
                        
                        // ADD EXERCISE BUTTON
                        Button(action: {
                            // bring up Exercise Editor View
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
                    }
                }
                
                Spacer()
                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Dismiss").foregroundColor(fgColor)
                }
            }
            
            // TOP TOOLBAR
            VStack {
                VStack {
                    Spacer().frame(height: 60)
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
                }
                .background(Color(.systemGray6))
//                .background(
//                    ZStack {
//                        BlurView(style: .systemUltraThinMaterial)
//                        Color(.systemGray6).opacity(0.65)
//                    }
//                )
                Spacer()
            }
            .edgesIgnoringSafeArea(.top)
            
            // BOTTOM TOOLBAR
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // CANCEL BUTTON ////////////////////
                    Button(action: {
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
                    
                    // EDIT BUTTON
                    Button(action: {
                        isPlanNameFocused = false
//                        reorderIsPresented = true
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
                    
                    Spacer()
                    
                    // SAVE BUTTON ////////////////////
                    Button(action: {
                        // add active plan to view model's plans
                        planViewModel.workoutPlans.append(planViewModel.activePlan)
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
                .frame(height: 82)
                .background(BlurView(style: .systemUltraThinMaterial))
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color(.systemGray6))
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
