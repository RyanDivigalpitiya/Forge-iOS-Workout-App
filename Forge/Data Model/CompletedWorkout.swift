import Foundation

struct CompletedWorkout: Identifiable, Encodable, Decodable {
    var id: UUID
    var dateCompleted: Date
    var elapsedTime: TimeInterval
    var workout: WorkoutPlan
    var completion: String
    
    // create new  CompletedWorkouts object with specified params
    init(date: Date, workout: WorkoutPlan, elapsedTime: TimeInterval, completion: String) {
        self.id = UUID()
        self.dateCompleted = date
        self.elapsedTime = elapsedTime
        self.workout = workout
        self.completion = completion
    }
}
