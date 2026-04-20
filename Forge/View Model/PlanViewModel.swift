import Foundation

class PlanViewModel: ObservableObject {

    @Published var workoutPlans: [WorkoutPlan]

    @Published var activePlan: WorkoutPlan
    @Published var activePlanIndex: Int
    @Published var activePlanMode: PlanEditorMode
    @Published var activePlanIsReadOnly: Bool = false

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.workoutPlans = []
        self.activePlan = WorkoutPlan()
        self.activePlanIndex = 0
        self.activePlanMode = .add
        self.workoutPlans = loadPlans()
        dedupePlanIdsIfNeeded()
    }

    init(mockPlans: [WorkoutPlan], userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.workoutPlans = mockPlans
        self.activePlan = mockPlans.first ?? WorkoutPlan()
        self.activePlanIndex = 0
        self.activePlanMode = .add
    }
}

// LOAD / SAVE / RE-ORDER / DELETE PERSISTANT DATA FUNCTIONS
extension PlanViewModel {
    func loadPlans() -> [WorkoutPlan] {
        if let workoutPlansData = userDefaults.data(forKey: "workoutPlans") {
            if let decodedData = try? JSONDecoder().decode([WorkoutPlan].self, from: workoutPlansData) {
                return decodedData
            } else { return [] }
        } else { return [] }
    }

    func savePlans() {
        if let encodedData = try? JSONEncoder().encode(workoutPlans) {
            userDefaults.set(encodedData, forKey: "workoutPlans")
        }
    }

    // handles re-ordering of plans
    func movePlan(from source: IndexSet, to destination: Int) {
        self.workoutPlans.move(fromOffsets: source, toOffset: destination)
        self.savePlans()
    }
        
    // handles deleting exercises while editing/adding plan
    func deletePlan(at offsets: IndexSet) {
        self.workoutPlans.remove(atOffsets: offsets)
        self.savePlans()
    }
    
    // handles re-ordering of exerices while editing/adding plan
    func moveExercise(from source: IndexSet, to destination: Int) {
        self.activePlan.exercises.move(fromOffsets: source, toOffset: destination)
    }
    
    // handles deleting exercises while editing/adding plan
    func deleteExercise(at offsets: IndexSet) {
        self.activePlan.exercises.remove(atOffsets: offsets)
    }

    func transferExercise(at exerciseIndex: Int, toPlans targetIndices: Swift.Set<Int>) {
        guard activePlan.exercises.indices.contains(exerciseIndex) else { return }
        let exercise = activePlan.exercises[exerciseIndex]
        for targetIndex in targetIndices {
            guard workoutPlans.indices.contains(targetIndex) else { continue }
            workoutPlans[targetIndex].exercises.append(exercise)
        }
        activePlan.exercises.remove(at: exerciseIndex)
        savePlans()
    }

    // Imports a plan received from another user. Strips completion state so the
    // plan arrives as a clean template, regenerates every UUID (plan / exercise
    // / set) so repeated imports of the same source never collide in the local
    // list, and auto-suffixes the name on collision.
    func importPlan(_ plan: WorkoutPlan) {
        var sanitized = plan
        sanitized.id = UUID()
        sanitized.lastCompleted = nil
        for exerciseIndex in sanitized.exercises.indices {
            sanitized.exercises[exerciseIndex].id = UUID()
            var clearedSets = sanitized.exercises[exerciseIndex].sets
            for setIndex in clearedSets.indices {
                clearedSets[setIndex].id = UUID()
                clearedSets[setIndex].completed = false
            }
            sanitized.exercises[exerciseIndex].sets = clearedSets
        }
        sanitized.name = uniqueName(for: sanitized.name)
        workoutPlans.append(sanitized)
        savePlans()
    }

    // Retroactive cleanup for users who already have duplicate plan UUIDs in
    // local storage (from the old importPlan path that preserved the source
    // UUID). Reassigns fresh UUIDs to every occurrence after the first so the
    // carousel's ForEach and scroll-position bindings can key uniquely.
    private func dedupePlanIdsIfNeeded() {
        var seen: Swift.Set<UUID> = []
        var changed = false
        for index in workoutPlans.indices {
            if seen.contains(workoutPlans[index].id) {
                workoutPlans[index].id = UUID()
                changed = true
            }
            seen.insert(workoutPlans[index].id)
        }
        if changed { savePlans() }
    }

    private func uniqueName(for proposed: String) -> String {
        let existing = Swift.Set(workoutPlans.map { $0.name })
        guard existing.contains(proposed) else { return proposed }
        let base = "\(proposed) (Imported)"
        if !existing.contains(base) { return base }
        var counter = 2
        while existing.contains("\(base) \(counter)") {
            counter += 1
        }
        return "\(base) \(counter)"
    }
}

// data manipulation to passed to views
extension PlanViewModel {
        
    func calculateWorkoutDuration(for plan: WorkoutPlan) -> Int {
        /**
        This function calculates the estimated duration of a workout based on a given `WorkoutPlan`.

        The function starts with some constants: a 60-second break timer after each set and a 3-second duration per rep within a set.

        It then iterates through each `Exercise` in the plan, and for each exercise, it iterates through its `Set` objects. For each set, the function adds the total time for the reps (rep count multiplied by rep time) plus the break time to a running total for the exercise.

        After calculating the total time for each exercise, the function subtracts the last break time (since there is no break after the last set of an exercise) and adds the result to a running total for the entire workout, right before adding in the time it takes to find and setup the exercise.

        If the final workout time is more than 60 seconds, the function converts it to minutes by dividing by 60. If the final workout time is less than 60 seconds, the function rounds down to 0, as this function does not account for second-accuracy estimation of workout duration.

        Parameters:
        - plan: A `WorkoutPlan` object containing `Exercise` and `Set` objects to calculate duration from.

        Returns:
        - The estimated workout duration in minutes. If the workout duration is less than a minute, it returns 0.
        */

        let timeInbetweenSets = 60*5 // 5 minutes in-between exercises
        let breakTime = 60 // 60 second break timer
        let repTime = 3 // 3 seconds per rep
        let exercisesWithSets = plan.exercises.filter { !$0.sets.isEmpty }
        
        guard !exercisesWithSets.isEmpty else { return 0 }
        
        //loop through sets and exercises while adding duration length to "workoutTime":
        var workoutTime = timeInbetweenSets // 5 minutes to find + set up the first exercise
        for exercise in exercisesWithSets {
            var exerciseTime = 0
            for set in exercise.sets {
                let repCount = set.reps
                exerciseTime = exerciseTime + repCount*repTime + breakTime
            }
            workoutTime = workoutTime + exerciseTime + timeInbetweenSets - breakTime
        }
        
        if workoutTime > 60 {
            workoutTime = Int(workoutTime / 60)
        } else {
            return 0 // if workoutTime is less than 60 seconds, simply round down to 0; no need for second-accuracy estimation of workout duration
        }
        return workoutTime
    }
    
    func isThereNonZeroDecimal(in number: Float) -> String {
        /**
        This function checks if the given floating-point number has a non-zero decimal value and returns a string representation of the number accordingly.

        If the number does not have a non-zero decimal value (i.e., if it's an integer), the function returns a string of the integer part of the number.

        If the number does have a non-zero decimal value, the function returns a string representation of the number, formatted to display up to one decimal place (e.g., '10.5').

        This function is used primarily for formatting purposes, for example, when displaying an exercise's weight (represented as a Float) in a user-friendly format.

        Parameters:
        - number: A `Float` value that needs to be checked for non-zero decimal values and converted into a string.

        Returns:
        - A `String` representation of the input number, formatted according to whether or not it has a non-zero decimal part.
        */

        let result = number.truncatingRemainder(dividingBy: 1) != 0 ? String(format: "%.1f", number) : String(Int(number))
        return String(result)
    }
}
