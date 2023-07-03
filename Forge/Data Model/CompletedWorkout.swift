import Foundation

struct CompletedWorkout: Identifiable, Encodable, Decodable {
    var id: UUID
    var dateCompleted: Date
    var elapsedTime: TimeInterval
    var workout: WorkoutPlan
    
    // create new  CompletedWorkouts object with specified params
    init(date: Date, workout: WorkoutPlan) {
        self.id = UUID()
        self.dateCompleted = date
        self.elapsedTime = 1800
        self.workout = workout
    }
}
