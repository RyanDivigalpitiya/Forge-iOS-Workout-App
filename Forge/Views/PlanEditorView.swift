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
    let setsFontSize = GlobalSettings.shared.setsFontSize // Font size used for text in set rows
    let setsSpacing: CGFloat = 5

    
    var body: some View {
        ZStack {
            VStack {
                HStack{
                    Spacer()
                    Text(planViewModel.activePlanMode == "AddMode" ? "Create New Plan" : "Edit Plan")
                        .font(.system(size: 40))
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
                                            .fontWeight(.bold)
                                            .foregroundColor(fgColor)
                                            .font(.system(size: 30))
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

                                                SetView(setIndex: setIndex, exerciseIndex: exerciseIndex, uniqueSets: true, displayLabelBKG: true)
                                            }
                                        }
                                    } else { // homogenous set: display 1 row: weight x reps x sets
                                        
                                        SetView(setIndex: 0, exerciseIndex: exerciseIndex, uniqueSets: false, displayLabelBKG: true)
                                    }
                                }
                            }
                            .padding(15) //.padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
                            .background(bgColor)
                            .cornerRadius(16)
                            .sheet(isPresented: $exerciseEditorIsPresented) {
                                
                                ExerciseEditorView(selectedDetent: $selectedDetent)
                                    .presentationDetents([.medium, .large], selection: $selectedDetent)
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
                        
                        Spacer().frame(height: 110)
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
    //                        ReorderDeleteView(mode: "ExerciseMode")
    //                            .environment(\.colorScheme, .dark)
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
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
