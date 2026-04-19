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
        case creating
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

    func createSession() async {
        disconnect()
        state = .creating

        var request = URLRequest(url: URL(string: "https://\(Self.serverHost)/sessions")!)
        request.httpMethod = "POST"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                state = .error("Server rejected session create")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let idString = json["sessionId"],
                  let id = UUID(uuidString: idString)
            else {
                state = .error("Unexpected server response")
                return
            }
            sessionId = id
            openSocket(sessionId: id)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func joinSession(id: UUID) {
        disconnect()
        sessionId = id
        openSocket(sessionId: id)
    }

    func disconnect() {
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        sessionId = nil
        myId = nil
        peerIds = []
        state = .idle
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
