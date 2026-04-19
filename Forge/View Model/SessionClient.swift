import Foundation

enum ServerMessage: Codable {
    case welcome(yourId: UUID, existingPeers: [UUID])
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case sessionFull
}

@MainActor
final class SessionClient: ObservableObject {

    static let serverHost = "expensive-installations-douglas-recording.trycloudflare.com"

    enum State: Equatable {
        case idle
        case connecting
        case waitingForPeer
        case connected
        case disconnected(reason: String)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var sessionId: UUID?
    @Published var myId: UUID?
    @Published var peerIds: [UUID] = []

    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?

    func createSession() {
        disconnect()
        let id = UUID()
        sessionId = id
        openSocket(sessionId: id)
    }

    func joinSession(id: UUID) {
        disconnect()
        sessionId = id
        openSocket(sessionId: id)
    }

    func reconnect() {
        guard let id = sessionId else { return }
        guard case .disconnected = state else { return }
        cleanupSocket()
        myId = nil
        peerIds = []
        openSocket(sessionId: id)
    }

    func disconnect() {
        cleanupSocket()
        sessionId = nil
        myId = nil
        peerIds = []
        state = .idle
    }

    private func cleanupSocket() {
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func shareLinkURL() -> URL? {
        guard let id = sessionId else { return nil }
        return URL(string: "forge://session/\(id.uuidString)")
    }

    private func openSocket(sessionId: UUID) {
        state = .connecting
        let url = URL(string: "wss://\(Self.serverHost)/sessions/\(sessionId.uuidString)")!
        let newTask = URLSession.shared.webSocketTask(with: url)
        task = newTask
        newTask.resume()
        receiveLoop = Task { [weak self] in
            await self?.readLoop(task: newTask)
        }
    }

    private func readLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                if case .string(let text) = message {
                    handle(incoming: text)
                }
            } catch {
                if !Task.isCancelled {
                    state = .disconnected(reason: error.localizedDescription)
                }
                return
            }
        }
    }

    private func handle(incoming text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data)
        else { return }

        switch message {
        case .welcome(let yourId, let existingPeers):
            myId = yourId
            peerIds = existingPeers
            state = existingPeers.isEmpty ? .waitingForPeer : .connected

        case .peerJoined(let peerId):
            if !peerIds.contains(peerId) {
                peerIds.append(peerId)
            }
            state = .connected

        case .peerLeft(let peerId):
            peerIds.removeAll { $0 == peerId }
            state = peerIds.isEmpty ? .waitingForPeer : .connected

        case .sessionFull:
            state = .error("Session is full (2 participants max)")
            task?.cancel(with: .goingAway, reason: nil)
        }
    }
}
