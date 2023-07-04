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
    @State var selectedDetent: PresentationDetent = .medium
    private let availableDetents: [PresentationDetent] = [.medium, .large]
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray: Color = Color(red: 0.33, green: 0.33, blue: 0.33)
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let screenHeight = UIScreen.main.bounds.height
    let setsFontSize: CGFloat = 20 // Font size used for text in set rows
    let setsSpacing: CGFloat = 3


    
    var body: some View {
        ZStack {
            
            // TITLE + PLAN NAMEFIELD + LIST OF EXERCISES
            VStack {
                HStack{
                    Spacer()
                    Text(planViewModel.activePlanMode == "AddMode" ? "Create New Plan" : "Edit Plan")
                        .font(.system(size: 40))
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    Spacer() 
                }
                
                TextField("Enter Plan Name Here", text: $planViewModel.activePlan.name)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 10)
                    .focused($isPlanNameFocused)
                    .autocapitalization(.words)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 30))
                
                // LIST OF EXERCISES
                ScrollView {
                    LazyVStack {
                        ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { exerciseIndex in
                            
                            // EDIT BUTTON
                            Button(action: {
                                exerciseViewModel.activeExerciseMode = "EditMode"
                                exerciseViewModel.activeExercise = planViewModel.activePlan.exercises[exerciseIndex]
                                exerciseViewModel.activeExerciseIndex = exerciseIndex
                                self.exerciseEditorIsPresented = true
                            }) {
                                VStack{
                                    HStack {
                                        Text(planViewModel.activePlan.exercises[exerciseIndex].name)
                                            .multilineTextAlignment(.leading)
                                            .fontWeight(.bold)
                                            .foregroundColor(fgColor)
                                            .font(.system(size: 30))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Image(systemName: "pencil.circle.fill")
                                            .resizable()
                                            .frame(width: 19, height: 19)
                                            .foregroundColor(.gray)
                                            .opacity(0.6)
                                    }
                                    if planViewModel.activePlan.exercises[exerciseIndex].areSetsUnique { // heterogenous set: display each unqiue set
                                        VStack(spacing: 25) {
                                            ForEach(planViewModel.activePlan.exercises[exerciseIndex].sets.indices, id: \.self) { setIndex in
                                                let set = planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex]
                                                
                                                // SET ROW (UNIQUE)
                                                HStack {
                                                    if setIndex+1 > 9 {
                                                        Text("Set \(setIndex+1)")
                                                            .font(.system(size: 16))
                                                            .foregroundColor(.white)
                                                            .frame(width: 67, height: 28)
                                                            .background(fgColor)
                                                            .cornerRadius(5)
                                                            .padding(.trailing, setsSpacing+2)
                                                    } else {
                                                        Text("Set \(setIndex+1)")
                                                            .font(.system(size: 16))
                                                            .foregroundColor(.white)
                                                            .frame(width: 58, height: 28)
                                                            .background(fgColor)
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

                                                
                                            }
                                        }
                                    } else { // homogenous set: display 1 row: weight x reps x sets
                                        HStack {
                                            if planViewModel.activePlan.exercises[exerciseIndex].sets.count > 9 {
                                                Text("\(planViewModel.activePlan.exercises[exerciseIndex].sets.count) sets")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .frame(width: 67, height: 28)
                                                    .background(fgColor)
                                                    .cornerRadius(5)
                                                    .padding(.trailing, setsSpacing+2)
                                            } else {
                                                Text("\(planViewModel.activePlan.exercises[exerciseIndex].sets.count) sets")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .frame(width: 58, height: 28)
                                                    .background(fgColor)
                                                    .cornerRadius(5)
                                                    .padding(.trailing, setsSpacing+2)

                                            }
                                            Text("\(Int(planViewModel.activePlan.exercises[exerciseIndex].sets[0].weight)) lb")
                                                .foregroundColor(.white)
                                                .padding(.trailing, setsSpacing)
                                            Image(systemName: "xmark")
                                                .resizable()
                                                .frame(width: 10, height: 10)
                                                .padding(.top,3)
                                                .foregroundColor(.gray)
                                                .opacity(0.6)
                                                .padding(.trailing, setsSpacing)
                                            Text("\(planViewModel.activePlan.exercises[exerciseIndex].sets[0].reps) reps")
                                                .foregroundColor(.gray)
                                                .opacity(0.6)
                                            Spacer()
                                        }
                                        .padding(.top, -8)
                                        .fontWeight(.bold)
                                        .font(.system(size: setsFontSize))
                                    }
                                }
                            }
                            .padding(15) //.padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
                            .background(bgColor)
                            .cornerRadius(16)
                            .sheet(isPresented: $exerciseEditorIsPresented) {
                                
                                ExerciseEditorView(selectedDetent: $selectedDetent)
                                    .presentationDetents([.medium, .large], selection: $selectedDetent)
                                    .presentationDragIndicator(.hidden)
                                    .environment(\.colorScheme, .dark)
                                
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        
                        
                        if planViewModel.activePlan.exercises.count > 0 {
                            Text("Tap an exercise to edit it")
                                .foregroundColor(darkGray)
                                .fontWeight(.bold)
                        }
                        
                        Spacer().frame(height: 130)
                    }
                    
                }
                
                Spacer()
            }
            
            
            // BOTTOM TOOLBAR
            VStack {
                Spacer()
                
                // BOTTOM TOOLBAR BUTTONS
                VStack {
                    // ADD EXERCISE BUTTON
                    HStack {
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
                            .padding(.horizontal)
                            .padding(.top)
                            .padding(.bottom, 8)
                            .foregroundColor(fgColor)
                        }
                        .sheet(isPresented: $exerciseEditorIsPresented) {
                            ExerciseEditorView(selectedDetent: $selectedDetent)
                                .background(.black)
                                .presentationDetents([.medium, .large], selection: $selectedDetent)
                                .presentationDragIndicator(.hidden)
                                .environment(\.colorScheme, .dark)
                        }

                    }
                    
                    Divider()
                        .padding(.horizontal,54)
                        .padding(.bottom,10)
                    
                    // CANCEL / SAVE / ORDER BUTTONS
                    HStack {
                        Spacer()
                        
                        // CANCEL BUTTON ////////////////////
                        Button(action: {
                            isPlanNameFocused = false
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
    //                        Image(systemName: "xmark.circle.fill")
    //                            .resizable()
    //                            .frame(width: 25, height: 25)

                            Text("Cancel")
                                .font(.headline)
                        }
                        .foregroundColor(fgColor)
                    
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
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .padding(.trailing, 3)
                                Text("Save")
    //                                .font(.headline)
                                    .font(.system(size: 23))
                                    .bold()
                            }
                            .frame(width: 109, height: 41)
                            .background(fgColor)
                            .foregroundColor(.black)
                            .cornerRadius(500)
                        }
    //                    .padding(.horizontal, 45)

                        
                        Spacer()
                        
                        // REORDER BUTTON
                        Button(action: {
                            isPlanNameFocused = false
                            reorderDeleteViewPresented = true
                        }) {
    //                        Image(systemName: "arrow.up.arrow.down.circle.fill")
    //                            .resizable()
    //                            .frame(width: 25, height: 25)
                            Text("Order")
                                .font(.headline)
                        }
                        .foregroundColor(fgColor)
                        .sheet(isPresented: $reorderDeleteViewPresented) {
                            ReorderDeleteView(mode: "ExerciseMode")
                                .environment(\.colorScheme, .dark)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 5)
                    
                    Spacer()

                }
                .padding(.bottom, 15)
                .frame(height: 150)
                .background(BlurView(style: .systemUltraThinMaterial))
            }
            .edgesIgnoringSafeArea(.bottom)
            
            if planViewModel.activePlan.exercises.count == 0 {
                VStack {
                    HStack {
                        Text("Tap").fontWeight(.bold)
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise").fontWeight(.bold)
                        Text("to add exercises")
                    }
                    .padding(.bottom, 10)
                    Image(systemName: "arrow.down")
                }
                .foregroundColor(darkGray)
            }
        }
        .background(.black)
        .onAppear {
//            isPlanNameFocused = planViewModel.activePlan.name == ""
        }
    }
}

struct PlanEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PlanEditorView()
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans)) // mockPlans: mockWorkoutPlans
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
