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
    @State private var isDoneCheckMarkVisible: Bool = false
    @State private var editMode: EditMode = .inactive
    @State private var exerciseToTransferIndex: Int? = nil
    @State private var showTransferSheet = false

    /// Drives the "newly added exercise bounces" animation. Same recipe
    /// as `WeightHistoryView.bounceEntry(id:)` /
    /// `PlanSuggestionView.bounceSuggestedPane()` — quick scale-up, slow
    /// spring back. Targets the just-appended exercise (new ones land
    /// at the end of `activePlan.exercises`).
    @State private var bouncingExerciseId: UUID? = nil
    @State private var bounceScale: CGFloat = 1.0

    private var isSaveDisabled: Bool {
        Validation.trimmedName(planViewModel.activePlan.name) == nil || planViewModel.activePlan.exercises.isEmpty
    }

    private var titleText: String {
        switch planViewModel.activePlanMode {
        case .add: return "Create New Plan"
        case .edit: return "Edit Plan"
        case .preview: return "Preview Plan"
        }
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
                    Text(titleText)
                        .font(.system(size: 40))
                        .fontWeight(.bold)
                        .foregroundColor(settings.fgColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .submitLabel(.done)
                    .disabled(planViewModel.activePlanIsReadOnly)
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
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    if !planViewModel.activePlanIsReadOnly {
                                        Image(systemName: "pencil.circle.fill")
                                            .resizable()
                                            .frame(width: 19, height: 19)
                                            .foregroundColor(.gray)
                                            .opacity(0.6)
                                    }
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
                        .disabled(planViewModel.activePlanIsReadOnly)
                        .padding(15)
                        .background(bgColor)
                        .cornerRadius(settings.cornerRadiusLarge)
                        .scaleEffect(exercise.id == bouncingExerciseId ? bounceScale : 1.0)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !planViewModel.activePlanIsReadOnly {
                                Button(role: .destructive) {
                                    planViewModel.deleteExercise(at: IndexSet(integer: exerciseIndex))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !planViewModel.activePlanIsReadOnly {
                                Button {
                                    exerciseToTransferIndex = exerciseIndex
                                    showTransferSheet = true
                                } label: {
                                    Label("Transfer", systemImage: "arrow.right.doc.on.clipboard")
                                }
                                .tint(.blue)
                            }
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
                    ExerciseEditorView()
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
                            .foregroundColor(planViewModel.activePlanIsReadOnly ? .gray : settings.fgColor)
                        }
                        .disabled(planViewModel.activePlanIsReadOnly)

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
                            } else if planViewModel.activePlanMode == .edit
                                   || (planViewModel.activePlanMode == .preview && !planViewModel.activePlanIsReadOnly) {
                                if planViewModel.workoutPlans.indices.contains(planViewModel.activePlanIndex) {
                                    planViewModel.workoutPlans[planViewModel.activePlanIndex] = planViewModel.activePlan
                                    planViewModel.savePlans()
                                }
                            }


                            let generator = UINotificationFeedbackGenerator()
                            generator.prepare()
                            generator.notificationOccurred(.success)

                            withAnimation(.easeInOut(duration: settings.animationSlow)) {
                                isDoneCheckMarkVisible = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                dismiss()
                            }
                        }) {
                            ZStack{
                                HStack {
                                    Text(planViewModel.activePlanIsReadOnly ? "View Only" : "Save")
                                        .font(.system(size: 20))
                                        .bold()
                                }
                                .frame(width: planViewModel.activePlanIsReadOnly ? 110 : 75, height: 35)
                                .background(planViewModel.activePlanIsReadOnly ? Color.gray : settings.fgColor)
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
                        .disabled(planViewModel.activePlanIsReadOnly || isSaveDisabled)

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
                        .foregroundColor(planViewModel.activePlanIsReadOnly ? .gray : settings.fgColor)
                        .disabled(planViewModel.activePlanIsReadOnly)

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

            if planViewModel.activePlan.exercises.count == 0 && !planViewModel.activePlanIsReadOnly {
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
        .onChange(of: planViewModel.activePlan.exercises.count) { oldCount, newCount in
            // Bounce only on adds (not deletes/reorders/imports). New
            // exercises are appended via `exercises.append(...)` in
            // ExerciseEditorView.saveExercise(), so the just-added one
            // is `last`. Fires immediately so the bounce coincides with
            // the row's first visible frame as the editor sheet
            // dismisses.
            if newCount > oldCount, let lastId = planViewModel.activePlan.exercises.last?.id {
                bounceExercise(id: lastId)
            }
        }
    }

    /// Bounces the newly added exercise: quick scale up, slow spring
    /// back. Mirrors `WeightHistoryView.bounceEntry(id:)`.
    private func bounceExercise(id: UUID) {
        bouncingExerciseId = id
        bounceScale = 1.0
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            bounceScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                bounceScale = 1.0
            }
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
