import Foundation

struct WorkoutPlan: Identifiable, Encodable, Decodable {
    var id: UUID
    var name: String
    var exercises: [Exercise]
    var lastCompleted: Date?
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.exercises = []
    }
    
    // create new WorkoutPlan object with specified params
    init(name: String, exercises: [Exercise], lastCompleted: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
        self.lastCompleted = lastCompleted
    }
    
    //function to create copy of WorkoutPlan object
    init(copy: WorkoutPlan) {
        self.id = copy.id
        self.name = copy.name
        self.exercises = copy.exercises
    }

}
