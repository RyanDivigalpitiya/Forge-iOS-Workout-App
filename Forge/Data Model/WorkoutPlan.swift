import Foundation

class WorkoutPlan: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var name: String
    var exercises: [Exercise]
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.exercises = []
    }
    
    // create new WorkoutPlan object with specified params
    init(id: UUID, name: String, exercises: [Exercise]) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
    }
    
    // equality operator for WorkoutPlan objects
    static func == (lhs: WorkoutPlan, rhs: WorkoutPlan) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.name == rhs.name &&
                lhs.exercises == lhs.exercises
    }
}
