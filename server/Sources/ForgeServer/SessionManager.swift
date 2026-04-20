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
        init(id: UUID) { self.id = id }
    }

    private var sessions: [UUID: Session] = [:]

    enum AddResult {
        case added(existingPeers: [PeerInfo], suggestedPlan: PlanSnapshot?)
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
        return .added(existingPeers: existingPeers, suggestedPlan: session.suggestedPlan)
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
    func setReady(sessionId: UUID, participantId: UUID, isReady: Bool) -> Bool {
        guard let session = sessions[sessionId] else { return false }
        guard var info = session.participants[participantId] else { return false }
        let wasAllReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        info.isReady = isReady
        session.participants[participantId] = info
        let nowAllReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        return nowAllReady && !wasAllReady
    }

    func broadcast(_ message: ServerMessage, in sessionId: UUID, except exceptId: UUID? = nil) {
        guard let session = sessions[sessionId] else { return }
        for (pid, info) in session.participants where pid != exceptId {
            info.continuation.yield(message)
        }
    }
}
