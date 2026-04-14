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
    @State var selectedDetent: PresentationDetent = .medium
    private let availableDetents: [PresentationDetent] = [.medium, .large]
    @State private var isDoneCheckMarkVisible: Bool = false
    @State private var editMode: EditMode = .inactive
    @State private var exerciseToTransferIndex: Int? = nil
    @State private var showTransferSheet = false

    private var isSaveDisabled: Bool {
        Validation.trimmedName(planViewModel.activePlan.name) == nil || planViewModel.activePlan.exercises.isEmpty
    }

    @EnvironmentObject var settings: GlobalSettings
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
                        .foregroundColor(settings.fgColor)
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
                List {
                    ForEach(planViewModel.activePlan.exercises) { exercise in
                      if let exerciseIndex = planViewModel.activePlan.exercises.firstIndex(where: { $0.id == exercise.id }) {
                        // EDIT BUTTON
                        Button(action: {
                            exerciseViewModel.activeExerciseMode = .edit
                            exerciseViewModel.activeExercise = planViewModel.activePlan.exercises[exerciseIndex]
                            exerciseViewModel.activeExerciseIndex = exerciseIndex
                            self.exerciseEditorIsPresented = true
                        }) {
                            VStack{
                                HStack {
                                    Text(exercise.name)
                                        .multilineTextAlignment(.leading)
                                        .fontWeight(.bold)
                                        .foregroundColor(settings.fgColor)
                                        .font(.system(size: 30))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    Image(systemName: "pencil.circle.fill")
                                        .resizable()
                                        .frame(width: 19, height: 19)
                                        .foregroundColor(.gray)
                                        .opacity(0.6)
                                }
                                if exercise.areSetsUnique { // heterogenous set: display each unqiue set
                                    VStack(spacing: 25) {
                                        ForEach(exercise.sets.indices, id: \.self) { setIndex in
                                            let set = exercise.sets[setIndex]
                                            SetView(
                                                content: .individual(set: set, index: setIndex),
                                                appearance: .standard
                                            )
                                        }
                                    }
                                } else { // homogenous set: display 1 row: weight x reps x sets
                                    SetView(
                                        content: .summary(
                                            count: exercise.sets.count,
                                            firstSet: exercise.sets.first
                                        ),
                                        appearance: .standard
                                    )
                                    .padding(.top, -8)
                                }
                            }
                        }
                        .padding(15)
                        .background(bgColor)
                        .cornerRadius(16)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                planViewModel.deleteExercise(at: IndexSet(integer: exerciseIndex))
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                exerciseToTransferIndex = exerciseIndex
                                showTransferSheet = true
                            } label: {
                                Label("Transfer", systemImage: "arrow.right.doc.on.clipboard")
                            }
                            .tint(.blue)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 15, bottom: 8, trailing: 15))
                      }
                    }
                    .onMove(perform: planViewModel.moveExercise)

                    if planViewModel.activePlan.exercises.count > 0 {
                        VStack(spacing: 4) {
                            Text("Tap an exercise to edit it")
                            Text("Swipe an exercise to manage it")
                        }
                            .foregroundColor(darkGray)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    }

                    // Bottom spacing to clear the toolbar
                    Color.clear
                        .frame(height: 130)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
                .sheet(isPresented: $exerciseEditorIsPresented) {
                    ExerciseEditorView(selectedDetent: $selectedDetent)
                        .presentationDetents([.medium, .large], selection: $selectedDetent)
                        .presentationDragIndicator(.hidden)
                        .environment(\.colorScheme, .dark)
                }
                .sheet(isPresented: $showTransferSheet) {
                    TransferExerciseView(
                        exerciseIndex: exerciseToTransferIndex ?? 0,
                        currentPlanId: planViewModel.activePlan.id
                    )
                    .presentationDetents([.medium])
                    .environment(\.colorScheme, .dark)
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
                            .foregroundColor(settings.fgColor)
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
                            Text("Cancel")
                                .font(.headline)
                                .frame(width: 55)
                        }
                        .foregroundColor(settings.fgColor)

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
                                .background(settings.fgColor)
                                .foregroundColor(.black)
                                .cornerRadius(500)
                                .opacity(isDoneCheckMarkVisible ? 0 : 1)

                                HStack {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 20))
                                        .bold()
                                }
                                .frame(width: 75, height: 35)
                                .background(settings.fgColor)
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
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }) {
                            Text(editMode == .active ? "Done" : "Order")
                                .font(.headline)
                                .frame(width: 55)
                        }
                        .foregroundColor(settings.fgColor)

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
        .disabled(isDoneCheckMarkVisible)
        .onAppear {
//            isPlanNameFocused = planViewModel.activePlan.name == ""
        }
    }
}

struct TransferExerciseView: View {
    @EnvironmentObject var planViewModel: PlanViewModel
    let exerciseIndex: Int
    let currentPlanId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlanIndices: Swift.Set<Int> = []

    @EnvironmentObject var settings: GlobalSettings

    var body: some View {
        VStack(spacing: 0) {
            Text("Transfer to Another Plan")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
                .padding(.top, 25)
                .padding(.bottom, 15)

            List {
                ForEach(planViewModel.workoutPlans.indices, id: \.self) { index in
                    let plan = planViewModel.workoutPlans[index]
                    if plan.id != currentPlanId {
                        Button {
                            if selectedPlanIndices.contains(index) {
                                selectedPlanIndices.remove(index)
                            } else {
                                selectedPlanIndices.insert(index)
                            }
                        } label: {
                            HStack {
                                Text(plan.name)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: selectedPlanIndices.contains(index)
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                    .foregroundColor(settings.fgColor)
                                    .font(.title3)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Button(action: {
                planViewModel.transferExercise(at: exerciseIndex, toPlans: selectedPlanIndices)
                dismiss()
            }) {
                Text("Transfer")
                    .font(.system(size: 20))
                    .bold()
                    .frame(width: 120, height: 40)
                    .background(settings.fgColor)
                    .foregroundColor(.black)
                    .cornerRadius(500)
            }
            .disabled(selectedPlanIndices.isEmpty)
            .opacity(selectedPlanIndices.isEmpty ? 0.4 : 1)
            .padding(.bottom, 20)
        }
        .background(.black)
    }
}

struct PlanEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PlanEditorView()
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans)) // mockPlans: mockWorkoutPlans
            .environmentObject(ExerciseViewModel())
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
