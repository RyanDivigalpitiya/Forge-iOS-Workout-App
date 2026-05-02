import Foundation

struct BodyWeightEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let weightLbs: Double

    init(id: UUID = UUID(), date: Date = Date(), weightLbs: Double) {
        self.id = id
        self.date = date
        self.weightLbs = weightLbs
    }
}
