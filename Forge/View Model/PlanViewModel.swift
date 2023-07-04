import Foundation

class PlanViewModel: ObservableObject {
    
    @Published var workoutPlans: [WorkoutPlan]
    
    @Published var activePlan: WorkoutPlan
    @Published var activePlanIndex: Int
    @Published var activePlanMode: String
    
    init() {
        self.workoutPlans = []
        self.activePlan = WorkoutPlan()
        self.activePlanIndex = 0
        self.activePlanMode = "AddMode"
        self.workoutPlans = loadPlans()
    }
    
    init(mockPlans: [WorkoutPlan]) {
        self.workoutPlans = mockPlans
        self.activePlan = mockPlans[0]
        self.activePlanIndex = 0
        self.activePlanMode = "AddMode"
    }
}

// LOAD / SAVE / RE-ORDER / DELETE PERSISTANT DATA FUNCTIONS
extension PlanViewModel {
    func loadPlans() -> [WorkoutPlan]{
        if let workoutPlansData = UserDefaults.standard.data(forKey: "workoutPlans") {
            if let decodedData = try? JSONDecoder().decode([WorkoutPlan].self, from: workoutPlansData) {
                return decodedData
            } else { return [] }
        } else { return [] }
    }
    
    func savePlans() {
        if let encodedData = try? JSONEncoder().encode(workoutPlans) {
            UserDefaults.standard.set(encodedData, forKey: "workoutPlans")
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
}

// data manipulation to passed to views
extension PlanViewModel {
        
    func calculateWorkoutDuration(for plan: WorkoutPlan) -> Int {
        /**
        This function calculates the estimated duration of a workout based on a given `WorkoutPlan`.

        The function starts with some constants: a 60-second break timer after each set and a 2-second duration per rep within a set.

        It then iterates through each `Exercise` in the plan, and for each exercise, it iterates through its `Set` objects. For each set, the function adds the total time for the reps (rep count multiplied by rep time) plus the break time to a running total for the exercise.

        After calculating the total time for each exercise, the function subtracts the last break time (since there is no break after the last set of an exercise) and adds the result to a running total for the entire workout.

        If the final workout time is more than 60 seconds, the function converts it to minutes by dividing by 60. If the final workout time is less than 60 seconds, the function rounds down to 0, as this function does not account for second-accuracy estimation of workout duration.

        Parameters:
        - plan: A `WorkoutPlan` object containing `Exercise` and `Set` objects to calculate duration from.

        Returns:
        - The estimated workout duration in minutes. If the workout duration is less than a minute, it returns 0.
        */

        
        let breakTime = 60 // 60 second break timer
        let repTime = 2 // 2 seconds per rep
        
        //loop through sets and exercises while adding duration length to "workoutTime":
        var workoutTime = 0
        for exercise in plan.exercises {
            var exerciseTime = 0
            for set in exercise.sets {
                let repCount = set.reps
                exerciseTime = exerciseTime + repCount*repTime + breakTime
            }
            workoutTime = workoutTime + (exerciseTime-60)
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
