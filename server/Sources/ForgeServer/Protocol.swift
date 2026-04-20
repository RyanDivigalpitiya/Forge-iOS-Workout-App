import Foundation

struct Profile: Codable, Sendable, Equatable {
    var name: String
    var photoData: Data?
}

struct PeerInfo: Codable, Sendable, Equatable {
    let peerId: UUID
    let profile: Profile?
}

struct SetSnapshot: Codable, Sendable, Equatable {
    let weight: Float
    let reps: Int
    let tillFailure: Bool
}

struct ExerciseSnapshot: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let sets: [SetSnapshot]
}

struct PlanSnapshot: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let exercises: [ExerciseSnapshot]
}

enum ServerMessage: Codable, Sendable {
    case welcome(yourId: UUID, peers: [PeerInfo], suggestedPlan: PlanSnapshot?)
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case planSuggested(peerId: UUID, plan: PlanSnapshot)
    case peerChat(peerId: UUID, text: String, timestamp: Date)
    case peerReadyChanged(peerId: UUID, isReady: Bool)
    case countdownStart(endDate: Date)
    case countdownCancelled
    case sessionFull
}

enum ClientMessage: Codable, Sendable {
    case profileUpdate(Profile)
    case suggestPlan(PlanSnapshot)
    case sendChat(text: String)
    case setReady(isReady: Bool)
}
