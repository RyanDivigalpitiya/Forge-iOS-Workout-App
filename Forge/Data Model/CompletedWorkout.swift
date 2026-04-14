import Foundation

struct CompletedWorkout: Identifiable, Encodable, Decodable {
    var id: UUID
    var dateCompleted: Date
    var elapsedTime: TimeInterval
    var workout: WorkoutPlan
    var completion: String
    var caloriesBurned: Double?
    
    init() {
        self.id = UUID()
        self.dateCompleted = Date()
        self.elapsedTime = TimeInterval()
        self.workout = WorkoutPlan()
        self.completion = "0 Minutes"
    }
    
    // create new  CompletedWorkouts object with specified params
    init(date: Date, workout: WorkoutPlan, elapsedTime: TimeInterval, completion: String, caloriesBurned: Double? = nil) {
        self.id = UUID()
        self.dateCompleted = date
        self.elapsedTime = elapsedTime
        self.workout = workout
        self.completion = completion
        self.caloriesBurned = caloriesBurned
    }
}
