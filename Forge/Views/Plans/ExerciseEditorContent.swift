import SwiftUI

/// The body of the exercise editor — top bar (X / title / Save), name field,
/// homogeneous picker, "Change Specific Sets" toggle, and heterogeneous rows.
///
/// Intentionally owns no `presentationDetents` modifier and no `dismiss()` —
/// those are the parent's responsibility. The parent provides:
///  - `selectedDetent` binding so this view can flip between the homo and
///    `.large` detents when the user toggles "Change Specific Sets".
///  - `homoModeDetent` so this view doesn't have to compute it twice.
///  - `onClose` (called by the X button).
///  - `onSaved` (called after a successful save flow).
///
/// Used by `ExerciseEditorView` (the standalone sheet) and by
/// `ExerciseOptionsSheet` (the in-workout morphing sheet).
struct ExerciseEditorContent: View {

    let focusNameOnAppear: Bool
    @Binding var selectedDetent: PresentationDetent
    let homoModeDetent: PresentationDetent
    let onClose: () -> Void
    let onSaved: () -> Void

    init(
        focusNameOnAppear: Bool = false,
        selectedDetent: Binding<PresentationDetent>,
        homoModeDetent: PresentationDetent,
        onClose: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.focusNameOnAppear = focusNameOnAppear
        self._selectedDetent = selectedDetent
        self.homoModeDetent = homoModeDetent
        self.onClose = onClose
        self.onSaved = onSaved
    }

    //-////////////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////

    @FocusState private var isNameFieldFocused: Bool // used to assign focus on exercise name textfield on appear

    //- ////////////////////////////////////////////////////////////////////////////
    // Data being inputted / edited:
    @State var exerciseName: String = ""
    // Homogenous Sets:
    @State private var homoSets: Int = 3
    @State private var homoWeight: Int = 5
    @State private var homoReps: Int = 12
    // Heterogenous Sets:
    @State private var heteroWeights: [Int] = [5, 5, 5]
    @State private var heteroReps: [Int] = [12, 12, 12]
    @State private var heteroFailure: [Bool] = [false, false, false]
    private let minSets = 1
    private let maxSets = 50
    private let minWeight = -100
    private let maxWeight = 500
    private let weightStep = 5
    private let minReps = 1
    private let maxReps = 500
    private var setsRange: [Int] { Array((minSets...maxSets).reversed()) }
    private var weightRange: [Int] { Array(stride(from: maxWeight, through: minWeight, by: -weightStep)) }
    private var repsRange: [Int] { Array((minReps...maxReps).reversed()) }
    private var isSaveDisabled: Bool { Validation.trimmedName(exerciseName) == nil }
    //- ////////////////////////////////////////////////////////////////////////////

    // Toggle for changing individual sets
    @State private var areSetsUnique = false
    @State private var homoHeteroControlsAreConnected: Bool = false
    @State private var editedExerciseStartedWithUniqueSets: Bool = false

    // Animation + Feedback parameters
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var homogenousSelectorHeight: CGFloat = 200
    @State private var heterogenousSelectorHeight: CGFloat = 0
    @State private var homogenousSelectorOpacity: Double = 1.0
    @State private var heterogenousSelectorOpacity: Double = 0
    @State private var heterogenousSetMaxViewHeight: CGFloat = CGFloat((150*3)+80)
    @State private var heterogenousSetRowHeight: CGFloat = 1000000

    @EnvironmentObject var settings: GlobalSettings
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let fontTitleSize: CGFloat = 35
    let darkGray = GlobalSettings.shared.editorDarkGray
    let screenWidth = UIScreen.main.bounds.width

    var body: some View {
        VStack {
            ScrollView {

                // TOP TOOLBAR TITLE
                HStack {

                    // close button (dismiss, no changes saved)
                    HStack {
                        Button(action: {
                            onClose()
                        }) {
                            ZStack {
                                Circle()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
                                Image(systemName: "xmark")
                                    .resizable()
                                    .frame(width: 11, height: 11)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(width: 0.2*screenWidth)

                    // Title text
                    HStack {
                        if exerciseViewModel.activeExerciseMode == .add {
                            Text("Add Exercise")
                                .font(.system(size:fontTitleSize))
                                .foregroundColor(settings.fgColor)
                                .fontWeight(.bold)
                        } else if exerciseViewModel.activeExerciseMode == .edit {
                            Text("Edit Exercise")
                                .font(.system(size:fontTitleSize))
                                .foregroundColor(settings.fgColor)
                                .fontWeight(.bold)
                        } else if exerciseViewModel.activeExerciseMode == .log {
                            Text("Log Change")
                                .font(.system(size:fontTitleSize))
                                .foregroundColor(settings.fgColor)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(width: 0.6*screenWidth)

                    // save button
                    HStack {
                        Button(action: {
                            saveExercise()
                        }) {
                            ZStack {
                                if exerciseViewModel.activeExerciseMode == .add {
                                    Circle()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
                                    Image(systemName: "arrow.up")
                                        .resizable()
                                        .frame(width: 13, height: 13)
                                        .fontWeight(.bold)
                                        .foregroundColor(settings.fgColor)
                                } else if exerciseViewModel.activeExerciseMode == .edit || exerciseViewModel.activeExerciseMode == .log {
                                    Circle()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
                                    Image(systemName: "checkmark")
                                        .resizable()
                                        .frame(width: 15, height: 13)
                                        .fontWeight(.bold)
                                        .foregroundColor(settings.fgColor)
                                        .padding(.top,1)
                                }
                            }
                        }
                        .disabled(isSaveDisabled)
                    }
                    .frame(width: 0.2*screenWidth)
            }
                .padding(.top,15)

                // EXERCISE NAME
                VStack{
                    TextField("Enter Exercise Name Here", text: $exerciseName)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .focused($isNameFieldFocused)
                        .autocapitalization(.words)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 23))
                        .padding(.bottom, 10)
                        .submitLabel(.done)
                        .onChange(of: exerciseName) { _, newValue in
                            if newValue.count > Validation.maxNameLength {
                                exerciseName = String(newValue.prefix(Validation.maxNameLength))
                            }
                        }
                }

                // HOMOGENOUS SET SELECTORS
                HomogeneousSetPicker(
                    sets: $homoSets,
                    weight: $homoWeight,
                    reps: $homoReps,
                    minSets: minSets, maxSets: maxSets,
                    minWeight: minWeight, maxWeight: maxWeight, weightStep: weightStep,
                    minReps: minReps, maxReps: maxReps
                )
                .frame(maxHeight: homogenousSelectorHeight)
                .clipped()
                .opacity(homogenousSelectorOpacity)

                // TOGGLE
                HStack(spacing: 10) {
                    Text("Change Specific Sets")
                        .foregroundColor(areSetsUnique ? settings.fgColor : darkGray)
                        .fontWeight(.bold)
                    Toggle("", isOn: $areSetsUnique)
                        .labelsHidden()
                        .onChange(of: areSetsUnique) { _, newValue in

                        if editedExerciseStartedWithUniqueSets {
                            // do nothing - here's why:
                            /*
                             when this editor view appears with unique sets to be edited,
                             this toggle will automatically be switched from false to true.
                             When this happens, we do not want to update the hetero data based on homo data because
                             the user did not trigger this switch, the UI did when loading itself.
                             So the first time this toggle is switched (when an exercise to-be-edited contains unique sets and
                             is loaded by the UI on appear), updateHeteroDataBasedOnHomoData() should not trigger.
                             However, after the data loads, and the user themselves switches toggle to false, then back to true again,
                             we want to always trigger updateHeteroDataBasedOnHomoData() from there on out.
                             Thus, we set editedExerciseStartedWithUniqueSets = false after this if-else statement
                             */
                        } else {
                            if newValue == false { // we're switching to viewing the homogenous sets
                                updateHomoDataBasedOnHeteroData()
                            } else { // we're switching to viewing the heterogenous sets
                                updateHeteroDataBasedOnHomoData()
                            }
                        }

                        editedExerciseStartedWithUniqueSets = false

                        selectedDetent = newValue ? .large : homoModeDetent

                        withAnimation(.easeInOut(duration: 0.3)) {
                            homogenousSelectorHeight = newValue ? 0 : 200
                            homogenousSelectorOpacity = newValue ? 0 : 1
                            heterogenousSelectorHeight = newValue ? heterogenousSetMaxViewHeight : 0
                            heterogenousSelectorOpacity = newValue ? 1 : 0
                        }
                    }
                }
                .frame(maxWidth: 280)
                .padding(.horizontal, 24)
                .padding(.top, areSetsUnique ? 0 : 20)

                // HETEROGENOUS SET ROWS + CONTROLS
                Group {
                    if !exerciseViewModel.activeExercise.sets.isEmpty {
                        HeterogeneousSetEditor(
                            weights: $heteroWeights,
                            reps: $heteroReps,
                            failure: $heteroFailure,
                            minWeight: minWeight, maxWeight: maxWeight, weightStep: weightStep,
                            minReps: minReps, maxReps: maxReps, maxSets: maxSets,
                            isSaveDisabled: isSaveDisabled,
                            onSave: { saveExercise() }
                        )
                        .onChange(of: heteroWeights) { _, newValue in
                            let count = newValue.count
                            heterogenousSetMaxViewHeight = CGFloat((count*Int(heterogenousSetRowHeight))+80)
                            homoSets = clampSetCount(count)
                        }
                    }
                }
                .frame(maxHeight: heterogenousSelectorHeight)
                .clipped()
                .opacity(heterogenousSelectorOpacity)


            Spacer()
            }

        }
        .onAppear {
            homoHeteroControlsAreConnected = false
            // initialize UI dimensions, labels + toggle based on activeExercise and activeMode
            // name field
            exerciseName = exerciseViewModel.activeExercise.name
            let sourceSets = exerciseViewModel.activeExercise.sets.isEmpty ? [Set()] : exerciseViewModel.activeExercise.sets
            // heterogenousSetMaxViewHeight
            let count = sourceSets.count
            heterogenousSetMaxViewHeight = CGFloat((Int(heterogenousSetRowHeight)*count)+80)
            // whether areSetsUnique toggle is switched to false/true (ie. should view show homogenous exercise or heterogenous set rows)
            areSetsUnique = exerciseViewModel.activeExercise.areSetsUnique
            if areSetsUnique {
                editedExerciseStartedWithUniqueSets = true
            }

            selectedDetent = areSetsUnique ? .large : homoModeDetent

            // LOAD UI WITH ACTIVE EXERCISE'S DATA: ////////////////////////////////////
            // clear hetero values and append values from activeExercise's set data
            heteroWeights.removeAll()
            heteroReps.removeAll()
            heteroFailure.removeAll()
            for set in sourceSets {
                heteroWeights.append(clampWeight(Int(set.weight.rounded())))
                heteroReps.append(clampReps(set.reps))
                heteroFailure.append(set.tillFailure)
            }

            // assign homo data values from activeExercise's data
            homoSets = clampSetCount(sourceSets.count)
            if let firstSet = sourceSets.first {
                homoWeight = clampWeight(Int(firstSet.weight.rounded()))
                homoReps = clampReps(firstSet.reps)
            } else {
                homoWeight = 5
                homoReps = 12
            }
            // -  //////////////////////////////////// //////////////////////////////////

            homoHeteroControlsAreConnected = true

            if focusNameOnAppear {
                // @FocusState set during a sheet's present transition gets
                // silently dropped by SwiftUI; ~0.4s lets the transition
                // settle before we ask for focus.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isNameFieldFocused = true
                }
            }
        }
    }
}

// view functions
extension ExerciseEditorContent {

    func saveExercise() {
        isNameFieldFocused = false

        guard let validName = Validation.trimmedName(exerciseName) else { return }
        exerciseName = validName

        // create list of sets that were edited
        var newSets: [Set] = []
        let existingExerciseIndex = exerciseViewModel.activeExerciseIndex
        // In .add mode, activeExerciseIndex is stale (it still points at whatever
        // exercise the user last logged/edited), so we must NOT inherit any state
        // from it. Only edit/log modes should pull completion state from an
        // existing exercise.
        let existingExercise: Exercise? = {
            guard exerciseViewModel.activeExerciseMode != .add else { return nil }
            return planViewModel.activePlan.exercises.indices.contains(existingExerciseIndex)
                ? planViewModel.activePlan.exercises[existingExerciseIndex]
                : nil
        }()

        if areSetsUnique {
            for index in heteroWeights.indices {
                guard heteroReps.indices.contains(index), heteroFailure.indices.contains(index) else { continue }
                let clampedWeight = Float(clampWeight(heteroWeights[index]))
                let clampedReps = clampReps(heteroReps[index])

                let completedValue: Bool
                if let existingExercise, index < existingExercise.sets.count {
                    completedValue = existingExercise.sets[index].completed
                } else {
                    completedValue = false
                }

                let newSet = Set(weight: clampedWeight, reps: clampedReps, tillFailure: heteroFailure[index], completed: completedValue)
                newSets.append(newSet)
            }
        } else {
            let clampedSets = clampSetCount(homoSets)
            let clampedWeight = Float(clampWeight(homoWeight))
            let clampedReps = clampReps(homoReps)

            for index in 0..<clampedSets {
                let completedValue: Bool
                if let existingExercise, index < existingExercise.sets.count {
                    completedValue = existingExercise.sets[index].completed
                } else {
                    completedValue = false
                }

                let newSet = Set(weight: clampedWeight, reps: clampedReps, tillFailure: false, completed: completedValue)
                newSets.append(newSet)
            }
        }

        if newSets.isEmpty {
            newSets = [Set()]
        }


        if exerciseViewModel.activeExerciseMode == .add {
            // create new exercise + append it to planViewModel's active plan
            let newExercise = Exercise(name: exerciseName, sets: newSets)
            planViewModel.activePlan.exercises.append(newExercise)

        } else if exerciseViewModel.activeExerciseMode == .edit || exerciseViewModel.activeExerciseMode == .log {
            // update active plan's exercises with the updated exercise while preserving identity.
            if var updatedExercise = existingExercise {
                updatedExercise.name = exerciseName
                updatedExercise.sets = newSets
                planViewModel.activePlan.exercises[existingExerciseIndex] = updatedExercise
            } else {
                let fallbackExercise = Exercise(name: exerciseName, sets: newSets)
                planViewModel.activePlan.exercises.append(fallbackExercise)
            }
        }

        feedbackGenerator.impactOccurred()
        onSaved()
    }

    func updateHeteroDataBasedOnHomoData() {
        guard homoHeteroControlsAreConnected else { return }
        let count = clampSetCount(homoSets)
        let weight = clampWeight(homoWeight)
        let reps = clampReps(homoReps)
        heteroWeights = Array(repeating: weight, count: count)
        heteroReps = Array(repeating: reps, count: count)
        heteroFailure = Array(repeating: false, count: count)
    }

    func updateHomoDataBasedOnHeteroData() {
        guard homoHeteroControlsAreConnected else { return }
        if let firstWeight = heteroWeights.first, let firstReps = heteroReps.first {
            homoSets = clampSetCount(heteroWeights.count)
            homoWeight = clampWeight(firstWeight)
            homoReps = clampReps(firstReps)
        } else {
            homoSets = 1
            homoWeight = 5
            homoReps = 12
        }
    }

    private func clampSetCount(_ count: Int) -> Int {
        min(max(count, minSets), maxSets)
    }

    private func clampWeight(_ weight: Int) -> Int {
        let clamped = min(max(weight, minWeight), maxWeight)
        // snap to weightStep
        return Int((Double(clamped) / Double(weightStep)).rounded()) * weightStep
    }

    private func clampReps(_ reps: Int) -> Int {
        min(max(reps, minReps), maxReps)
    }
}
