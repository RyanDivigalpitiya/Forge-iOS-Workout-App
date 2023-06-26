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
}

// data manipulation to passed to views
extension PlanViewModel {
    
    func calculateWorkoutDuration(for workout: WorkoutPlan) -> Int {
        /*
         calculates how many minutes a workout will take by adding up the minutes
         each exercise takes and the breaks in between
         */
        
        let repTimeInSeconds = 2
        let restTimeInSeconds = 60
        
        var totalWorkoutTimeInSeconds = 0
        
        for exercise in workout.exercises {
            // Calculate the time taken for the exercise
            let exerciseTimeInSeconds = Int(exercise.reps) * repTimeInSeconds
            // Add the time for the exercise to the total workout time
            totalWorkoutTimeInSeconds += exerciseTimeInSeconds
            // Calculate the rest time inbetween sets
            let restTimeInSeconds  = Int(exercise.sets) * restTimeInSeconds - 60 // subtract 60 bcz we do not rest after last set
            // Add the time taken during rests inbetween sets
            totalWorkoutTimeInSeconds += restTimeInSeconds
            // Add rest time after each set except for the last one
            if exercise != workout.exercises.last {
                totalWorkoutTimeInSeconds += restTimeInSeconds
            }
        }
        
        return totalWorkoutTimeInSeconds / 60
    }
    
    func isThereNonZeroDecimal(in number: Float) -> String {
        // if 'number' does not have a non-zero decimal value, func will return a string containing only the integer of input
        // if 'number' has a non-zero decimal value, func will return a string containing only the first decimal ie. '10.5'
        // this is used for formatting purposes when displaying exercise.weight: Float as a "better-looking" string
        let result = number.truncatingRemainder(dividingBy: 1) != 0 ? String(format: "%.1f", number) : String(Int(number))
        return String(result)
    }
}
