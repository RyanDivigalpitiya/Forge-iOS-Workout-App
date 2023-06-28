import Foundation

struct CompletedWorkout: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var dateCompleted: Date
    var workout: WorkoutPlan
    
    // create new  CompletedWorkouts object with specified params
    init(id: UUID, date: Date, workout: WorkoutPlan) {
        self.id = id
        self.dateCompleted = date
        self.workout = workout
    }
    
    // equality operator for CompletedWorkouts objects
    static func == (lhs: CompletedWorkout, rhs: CompletedWorkout) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.dateCompleted == rhs.dateCompleted &&
                lhs.workout == rhs.workout
    }
}
