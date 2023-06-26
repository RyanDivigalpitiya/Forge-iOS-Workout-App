import Foundation

class CompletedWorkouts: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var date: Date
    var workout: WorkoutPlan
    
    // create new  CompletedWorkouts object with specified params
    init(id: UUID, date: Date, workout: WorkoutPlan) {
        self.id = id
        self.date = date
        self.workout = workout
    }
    
    // equality operator for CompletedWorkouts objects
    static func == (lhs: CompletedWorkouts, rhs: CompletedWorkouts) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.date == rhs.date &&
                lhs.workout == rhs.workout
    }
}
