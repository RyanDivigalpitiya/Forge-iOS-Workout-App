import Foundation

struct Set: Identifiable, Encodable, Decodable {
    var id: UUID
    var weight: Float
    var reps: Int
    var tillFailure: Bool
    var completed: Bool
    
    // empty initializer
    init() {
        self.id = UUID()
        self.weight = 5.0
        self.reps = 12
        self.tillFailure = false
        self.completed = false
    }
    
    init(weight: Float, reps: Int, tillFailure: Bool) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.tillFailure = tillFailure
        self.completed = false
    }
}
    