import Foundation

actor SessionManager {
    static let shared = SessionManager()

    static let capacity = 2

    private final class Session {
        let id: UUID
        struct ParticipantInfo {
            let continuation: AsyncStream<ServerMessage>.Continuation
            var profile: Profile?
            var isReady: Bool = false
        }
        var participants: [UUID: ParticipantInfo] = [:]
        var suggestedPlan: PlanSnapshot?
        // Set when setReady triggers a startWorkout broadcast; persists for
        // the lifetime of the session so a phone that disconnects mid-
        // workout and re-joins can be routed straight back into the active
        // workout instead of the plan-suggestion screen. Cleared implicitly
        // when the session is deleted (last participant leaves).
        var workoutInProgress: PlanSnapshot?
        init(id: UUID) { self.id = id }
    }

    private var sessions: [UUID: Session] = [:]

    enum AddResult {
        case added(existingPeers: [PeerInfo], suggestedPlan: PlanSnapshot?, workoutInProgress: PlanSnapshot?)
        case sessionFull
    }

    func addParticipant(
        sessionId: UUID,
        participantId: UUID,
        continuation: AsyncStream<ServerMessage>.Continuation
    ) -> AddResult {
        let session = sessions[sessionId] ?? {
            let new = Session(id: sessionId)
            sessions[sessionId] = new
            return new
        }()
        if session.participants.count >= Self.capacity { return .sessionFull }
        let existingPeers: [PeerInfo] = session.participants.map { pid, info in
            PeerInfo(peerId: pid, profile: info.profile)
        }
        session.participants[participantId] = Session.ParticipantInfo(
            continuation: continuation,
            profile: nil
        )
        return .added(
            existingPeers: existingPeers,
            suggestedPlan: session.suggestedPlan,
            workoutInProgress: session.workoutInProgress
        )
    }

    /// Marks the session as having a workout actively in progress with the
    /// given plan snapshot. Called after setReady's all-ready transition
    /// triggers a startWorkout broadcast, so a phone that disconnects and
    /// re-joins can be re-routed straight to the workout view.
    func setWorkoutInProgress(sessionId: UUID, plan: PlanSnapshot?) {
        sessions[sessionId]?.workoutInProgress = plan
    }

    func removeParticipant(sessionId: UUID, participantId: UUID) {
        guard let session = sessions[sessionId] else { return }
        session.participants.removeValue(forKey: participantId)
        if session.participants.isEmpty {
            sessions.removeValue(forKey: sessionId)
        }
    }

    func updateProfile(sessionId: UUID, participantId: UUID, profile: Profile) {
        guard let session = sessions[sessionId] else { return }
        guard var info = session.participants[participantId] else { return }
        info.profile = profile
        session.participants[participantId] = info
    }

    func updateSuggestedPlan(sessionId: UUID, plan: PlanSnapshot) {
        sessions[sessionId]?.suggestedPlan = plan
    }

    /// Updates the participant's ready flag. Returns true if this update
    /// just made everyone in the session ready — the caller should
    /// broadcast `.startWorkout` to all participants. Workout entry is
    /// immediate; the WorkoutInProgressView already has its own 3-second
    /// starting countdown, so the collab layer doesn't add one.
    /// Side effect: when this transition fires, the session's
    /// workoutInProgress is set to the current suggestedPlan so future
    /// re-joiners can be routed straight back into the active workout.
    func setReady(sessionId: UUID, participantId: UUID, isReady: Bool) -> Bool {
        guard let session = sessions[sessionId] else { return false }
        guard var info = session.participants[participantId] else { return false }
        let wasAllReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        info.isReady = isReady
        session.participants[participantId] = info
        let nowAllReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        let justStarted = nowAllReady && !wasAllReady
        if justStarted {
            session.workoutInProgress = session.suggestedPlan
        }
        return justStarted
    }

    func broadcast(_ message: ServerMessage, in sessionId: UUID, except exceptId: UUID? = nil) {
        guard let session = sessions[sessionId] else { return }
        for (pid, info) in session.participants where pid != exceptId {
            info.continuation.yield(message)
        }
    }
}
