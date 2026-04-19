import Foundation

actor SessionManager {
    static let shared = SessionManager()

    static let capacity = 2

    private final class Session {
        let id: UUID
        struct ParticipantInfo {
            let continuation: AsyncStream<ServerMessage>.Continuation
            var profile: Profile?
        }
        var participants: [UUID: ParticipantInfo] = [:]
        init(id: UUID) { self.id = id }
    }

    private var sessions: [UUID: Session] = [:]

    enum AddResult {
        case added(existingPeers: [PeerInfo])
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
        return .added(existingPeers: existingPeers)
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

    func broadcast(_ message: ServerMessage, in sessionId: UUID, except exceptId: UUID? = nil) {
        guard let session = sessions[sessionId] else { return }
        for (pid, info) in session.participants where pid != exceptId {
            info.continuation.yield(message)
        }
    }
}
