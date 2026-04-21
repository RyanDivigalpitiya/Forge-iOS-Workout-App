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
    case welcome(yourId: UUID, peers: [PeerInfo], suggestedPlan: PlanSnapshot?, workoutInProgress: PlanSnapshot?)
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case planSuggested(peerId: UUID, plan: PlanSnapshot)
    case peerChat(peerId: UUID, text: String, timestamp: Date)
    case peerReadyChanged(peerId: UUID, isReady: Bool)
    case startWorkout
    case peerSetCompletion(peerId: UUID, exerciseId: UUID, setIndex: Int, completed: Bool)
    case peerPositionUpdated(peerId: UUID, exerciseIndex: Int, setIndex: Int, isResting: Bool)
    case peerBreakTimerChanged(peerId: UUID, endDate: Date?, exerciseIndex: Int, setIndex: Int)
    case sessionFull
}

enum ClientMessage: Codable, Sendable {
    case profileUpdate(Profile)
    case suggestPlan(PlanSnapshot)
    case sendChat(text: String)
    case setReady(isReady: Bool)
    case setCompletion(exerciseId: UUID, setIndex: Int, completed: Bool)
    case positionUpdate(exerciseIndex: Int, setIndex: Int, isResting: Bool)
    case breakTimerUpdate(endDate: Date?, exerciseIndex: Int, setIndex: Int)
}
