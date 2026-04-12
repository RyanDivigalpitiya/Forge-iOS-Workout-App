import SwiftUI

struct PlanEditorView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-/////////////////////////////////////////////////
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPlanNameFocused: Bool // used to assign focus on plan name textfield on appear
    @State private var exerciseEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    @State var selectedDetent: PresentationDetent = .medium
    private let availableDetents: [PresentationDetent] = [.medium, .large]
    @State private var isDoneCheckMarkVisible: Bool = false
    
    private var isSaveDisabled: Bool { Validation.trimmedName(planViewModel.activePlan.name) == nil }

    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray = GlobalSettings.shared.editorDarkGray
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setsFontSize = GlobalSettings.shared.setsFontSize
    let setsSpacing = GlobalSettings.shared.setsSpacing


    
    var body: some View {
        ZStack {
            
            // TITLE + PLAN NAMEFIELD + LIST OF EXERCISES
            VStack {
                HStack{
                    Spacer()
                    Text(planViewModel.activePlanMode == .add ? "Create New Plan" : "Edit Plan")
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
                    .submitLabel(.done)
                    .onChange(of: planViewModel.activePlan.name) { _, newValue in
                        if newValue.count > Validation.maxNameLength {
                            planViewModel.activePlan.name = String(newValue.prefix(Validation.maxNameLength))
                        }
                    }
                
                // LIST OF EXERCISES
                ScrollView {
                    LazyVStack {
                        ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { exerciseIndex in
                            
                            // EDIT BUTTON
                            Button(action: {
                                exerciseViewModel.activeExerciseMode = .edit
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
                                                SetView(
                                                    content: .individual(set: set, index: setIndex),
                                                    appearance: .standard
                                                )
                                            }
                                        }
                                    } else { // homogenous set: display 1 row: weight x reps x sets
                                        SetView(
                                            content: .summary(
                                                count: planViewModel.activePlan.exercises[exerciseIndex].sets.count,
                                                firstSet: planViewModel.activePlan.exercises[exerciseIndex].sets.first
                                            ),
                                            appearance: .standard
                                        )
                                        .padding(.top, -8)
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
                            exerciseViewModel.activeExerciseMode = .add
                            exerciseViewModel.activeExercise = Exercise()
                            self.exerciseEditorIsPresented = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("New Exercise").fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            .padding(.bottom, 8)
                            .padding(.trailing, 10)
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
                            dismiss()
                        }) {
    //                        Image(systemName: "xmark.circle.fill")
    //                            .resizable()
    //                            .frame(width: 25, height: 25)

                            Text("Cancel")
                                .font(.headline)
                                .frame(width: 55)
                        }
                        .foregroundColor(fgColor)
                    
                        Spacer()
                        
                        // SAVE BUTTON ////////////////////
                        Button(action: {
                            isPlanNameFocused = false
                            guard let validName = Validation.trimmedName(planViewModel.activePlan.name) else { return }
                            planViewModel.activePlan.name = validName
                            if planViewModel.activePlanMode == .add {
                                planViewModel.workoutPlans.append(planViewModel.activePlan)
                                planViewModel.savePlans()
                            } else if planViewModel.activePlanMode == .edit {
                                if planViewModel.workoutPlans.indices.contains(planViewModel.activePlanIndex) {
                                    planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
                                    planViewModel.savePlans()
                                }
                            }
                            

                            let generator = UINotificationFeedbackGenerator()
                            generator.prepare()
                            generator.notificationOccurred(.success)

                            withAnimation(.easeInOut(duration: 1)) {
                                isDoneCheckMarkVisible = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                dismiss()
                            }
                        }) {
                            ZStack{
                                HStack {
                                    Text("Save")
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
                        .disabled(isSaveDisabled)
                        
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
                                .frame(width: 55)
                        }
                        .foregroundColor(fgColor)
                        .sheet(isPresented: $reorderDeleteViewPresented) {
                            ReorderDeleteView(mode: .exercise)
                                .presentationDetents([.medium, .large])
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
                        Text("Tap")
                        Image(systemName: "plus.circle.fill")
                        Text("New Exercise").fontWeight(.bold)
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
