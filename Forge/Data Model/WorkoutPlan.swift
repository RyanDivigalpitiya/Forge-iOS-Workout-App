import Foundation

struct WorkoutPlan: Identifiable, Encodable, Decodable {
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
    init(name: String, exercises: [Exercise]) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
    }
}
