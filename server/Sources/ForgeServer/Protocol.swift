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
    /// Broadcast when a peer taps "Join Session →" (the explicit profile
    /// commit). Receivers track committed peers separately from
    /// `peerProfiles` so the auto-nav-to-PlanSuggestionView gate fires
    /// only on commits, not in-progress edits delivered via
    /// `peerProfileUpdated`.
    case peerProfileSubmitted(peerId: UUID)
    case sessionFull
    /// Broadcast when a peer taps Done in `WorkoutInProgressView`. The
    /// finishing peer disconnects immediately afterwards; the still-working
    /// peer surfaces a transient "Friend finished" banner so the
    /// disconnect doesn't read as a generic drop. Server clears
    /// `workoutInProgress` so any rejoiner doesn't get auto-routed back
    /// into a now-orphaned workout.
    case peerFinished(peerId: UUID)
    /// Broadcast when a peer taps Cancel in `WorkoutInProgressView`. Same
    /// semantics as `peerFinished` but distinguishes the "left the session"
    /// exit path from the "finished their workout" exit path so the
    /// remaining peer's banner copy can match.
    case peerCancelled(peerId: UUID)
}

enum ClientMessage: Codable, Sendable {
    case profileUpdate(Profile)
    case suggestPlan(PlanSnapshot)
    case sendChat(text: String)
    case setReady(isReady: Bool)
    case setCompletion(exerciseId: UUID, setIndex: Int, completed: Bool)
    case positionUpdate(exerciseIndex: Int, setIndex: Int, isResting: Bool)
    case breakTimerUpdate(endDate: Date?, exerciseIndex: Int, setIndex: Int)
    /// Host-only write for the solo → joint promotion flow. The iOS host
    /// creates a session mid-solo-workout, sends this message with the
    /// plan snapshot, and shares the sessionId URL. Any peer that joins
    /// afterwards gets `workoutInProgress` in their `welcome` and
    /// auto-routes straight into `WorkoutInProgressView`. No broadcast
    /// to existing peers — they'll read the value on their next welcome
    /// (e.g. after a reconnect).
    case setWorkoutInProgress(PlanSnapshot?)
    /// Sent when the user taps "Join Session →" — distinct from the
    /// live-edit `profileUpdate` so peers can differentiate "still
    /// entering their info" from "explicitly committed". No payload —
    /// the latest `profileUpdate` carries the profile data; this just
    /// flips the committed flag on the receiver side.
    case profileSubmitted
    /// Sent by `WorkoutInProgressView.finishWorkout()` immediately before
    /// `disconnect()`. Server fans out as `peerFinished` and clears
    /// `workoutInProgress` for the session.
    case workoutFinished
    /// Sent by `WorkoutInProgressView.cancelWorkout()` immediately before
    /// `disconnect()`. Server fans out as `peerCancelled` and clears
    /// `workoutInProgress` for the session.
    case workoutCancelled
}
