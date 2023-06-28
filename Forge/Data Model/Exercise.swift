import Foundation

struct Exercise: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var name: String
    
    var weight: Float
    var reps: Int
    var sets: Int
    
    var setCompletions: [Bool]
    var completed: Bool
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        
        self.weight = 5
        self.reps = 12
        self.sets = 3
        
        self.setCompletions = [false,false,false]
        self.completed = false
    }
    
    // create new Exercise object with specified params
    init(id: UUID, name: String, weight: Float, reps: Int, sets: Int, setCompletions: [Bool], completed: Bool) {
        self.id = id
        self.name = name
        
        self.weight = weight
        self.reps = reps
        self.sets = sets
        
        self.setCompletions = setCompletions
        self.completed = completed
    }
    
    // equality operator for Exercise objects
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.name == rhs.name &&
                lhs.weight == rhs.weight &&
                lhs.reps == rhs.reps &&
                lhs.sets == rhs.sets &&
                lhs.setCompletions == rhs.setCompletions &&
                lhs.completed == rhs.completed
    }
}
