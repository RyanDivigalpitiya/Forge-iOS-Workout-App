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
    /// Per-gap rest durations (length == sets.count - 1 when present).
    /// Optional for backward-compat with older clients that don't send the
    /// field. Server is opaque — forwards what it sees.
    let breakDurations: [Int]?
}

struct PlanSnapshot: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let exercises: [ExerciseSnapshot]
    /// Stable identity preserved through imports. Receiver uses this to
    /// recognize "descended from the same source" plans even after edits
    /// have made the structures (and therefore fingerprints) diverge.
    let lineageId: UUID?
    /// SHA-256 over ordered (lowercased+trimmed exerciseName, setCount)
    /// pairs. Defines structural equality for same-plan detection. Receiver
    /// matches against local plans' fingerprints to decide whether to use
    /// its own copy (preserving local weights/reps) or import the snapshot.
    let fingerprint: String?
}

enum ServerMessage: Codable, Sendable {
    case welcome(yourId: UUID, peers: [PeerInfo], suggestedPlan: PlanSnapshot?, workoutInProgress: PlanSnapshot?)
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    /// Broadcast when a peer sends `goingBackground` (iOS app moved off-screen).
    /// The other peer can show a subtle "stepped away" indicator instead of
    /// the loud "Friend disconnected" UI. The slot stays alive on the server
    /// for 5 minutes; if the peer doesn't return in that window, server fires
    /// `peerLeft` (true disconnect path).
    case peerAway(peerId: UUID)
    /// Broadcast when an away peer reconnects (reconnect-into-away-slot
    /// rebind), or when a still-connected away peer sends an explicit
    /// `returningToForeground`. Receiver clears the away indicator.
    case peerReturned(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case planSuggested(peerId: UUID, plan: PlanSnapshot)
    case peerChat(peerId: UUID, messageId: UUID, text: String, timestamp: Date)
    /// Broadcast when a peer adds, replaces, or removes their reaction on a
    /// chat bubble. `emoji == nil` is the remove case. Reactions aren't
    /// persisted server-side (same as chat history) — pure relay.
    case peerReactionChanged(peerId: UUID, messageId: UUID, emoji: String?)
    case peerReadyChanged(peerId: UUID, isReady: Bool)
    case startWorkout
    /// Set-completion sync uses positional indices, not exercise UUIDs,
    /// because Phase C same-plan detection means each peer may be working
    /// out from their own local plan with their own UUIDs. Both peers'
    /// plans have identical structure (fingerprint match), so positional
    /// indexing addresses the same logical exercise on both phones.
    case peerSetCompletion(peerId: UUID, exerciseIndex: Int, setIndex: Int, completed: Bool)
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
    case sendChat(messageId: UUID, text: String)
    /// Sender adds, replaces, or removes their reaction on a previously-sent
    /// chat message. `emoji == nil` is the remove case. Server fans out as
    /// `peerReactionChanged` to other peers.
    case setReaction(messageId: UUID, emoji: String?)
    case setReady(isReady: Bool)
    case setCompletion(exerciseIndex: Int, setIndex: Int, completed: Bool)
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
    /// Sent by the iOS client when `scenePhase` transitions to `.background`
    /// — iOS gives the app ~5s of background runtime before suspending,
    /// during which we flush this message over the live WS so the server
    /// can mark the slot "away" before the OS kills the socket. Without
    /// this, every brief app-switch by one friend surfaces a "Friend
    /// disconnected" banner on the other phone.
    case goingBackground
    /// Sent by the iOS client when `scenePhase` transitions back to
    /// `.active`. The reconnect-into-away-slot path also implicitly clears
    /// the away state (server broadcasts `peerReturned` in `addParticipant`'s
    /// `.rebound` case), so this message is mainly a defensive fallback for
    /// the rare case where the WS survived backgrounding (no reconnect
    /// needed) but the server still has us flagged as away.
    case returningToForeground
}
