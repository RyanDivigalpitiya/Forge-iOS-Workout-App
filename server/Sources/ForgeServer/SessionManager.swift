import Foundation

actor SessionManager {
    static let shared = SessionManager()

    static let capacity = 2

    private final class Session {
        let id: UUID
        var participants: [UUID: AsyncStream<ServerMessage>.Continuation] = [:]
        init(id: UUID) { self.id = id }
    }

    private var sessions: [UUID: Session] = [:]

    enum AddResult {
        case added(existingPeers: [UUID])
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
        let existingPeers = Array(session.participants.keys)
        session.participants[participantId] = continuation
        return .added(existingPeers: existingPeers)
    }

    func removeParticipant(sessionId: UUID, participantId: UUID) {
        guard let session = sessions[sessionId] else { return }
        session.participants.removeValue(forKey: participantId)
        if session.participants.isEmpty {
            sessions.removeValue(forKey: sessionId)
        }
    }

    func broadcast(_ message: ServerMessage, in sessionId: UUID, except exceptId: UUID? = nil) {
        guard let session = sessions[sessionId] else { return }
        for (pid, continuation) in session.participants where pid != exceptId {
            continuation.yield(message)
        }
    }
}
