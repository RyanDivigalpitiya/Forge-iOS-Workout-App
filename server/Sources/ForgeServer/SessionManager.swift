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
        var countdownEndDate: Date?
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

    struct ReadyUpdate {
        /// Non-nil if the server just started a countdown. All participants
        /// should be sent `countdownStart(endDate:)` with this date.
        let newCountdownEndDate: Date?
        /// True if the server just cancelled an in-flight countdown (because
        /// a participant un-readied). All participants should be sent
        /// `countdownCancelled`.
        let countdownCancelled: Bool
    }

    func setReady(sessionId: UUID, participantId: UUID, isReady: Bool) -> ReadyUpdate {
        guard let session = sessions[sessionId] else {
            return ReadyUpdate(newCountdownEndDate: nil, countdownCancelled: false)
        }
        guard var info = session.participants[participantId] else {
            return ReadyUpdate(newCountdownEndDate: nil, countdownCancelled: false)
        }
        info.isReady = isReady
        session.participants[participantId] = info

        let allReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        let countdownActive = session.countdownEndDate != nil

        if allReady && !countdownActive {
            let endDate = Date().addingTimeInterval(3)
            session.countdownEndDate = endDate
            return ReadyUpdate(newCountdownEndDate: endDate, countdownCancelled: false)
        }
        if !allReady && countdownActive {
            session.countdownEndDate = nil
            return ReadyUpdate(newCountdownEndDate: nil, countdownCancelled: true)
        }
        return ReadyUpdate(newCountdownEndDate: nil, countdownCancelled: false)
    }

    /// Called when a participant disconnects — cancels any in-flight
    /// countdown since we no longer have both participants.
    func clearReadyState(sessionId: UUID, participantId: UUID) -> Bool {
        guard let session = sessions[sessionId] else { return false }
        if var info = session.participants[participantId] {
            info.isReady = false
            session.participants[participantId] = info
        }
        if session.countdownEndDate != nil {
            session.countdownEndDate = nil
            return true  // caller should broadcast countdownCancelled
        }
        return false
    }

    func broadcast(_ message: ServerMessage, in sessionId: UUID, except exceptId: UUID? = nil) {
        guard let session = sessions[sessionId] else { return }
        for (pid, info) in session.participants where pid != exceptId {
            info.continuation.yield(message)
        }
    }
}
