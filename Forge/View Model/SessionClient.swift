import Foundation

struct Profile: Codable, Equatable {
    var name: String
    var photoData: Data?
}

struct PeerInfo: Codable, Equatable {
    let peerId: UUID
    let profile: Profile?
}

enum ServerMessage: Codable {
    case welcome(yourId: UUID, peers: [PeerInfo])
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case sessionFull
}

enum ClientMessage: Codable {
    case profileUpdate(Profile)
}

@MainActor
final class SessionClient: ObservableObject {

    static let serverHost = "expensive-installations-douglas-recording.trycloudflare.com"
    private static let profileKey = "collabProfile"

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
    @Published var peerProfiles: [UUID: Profile] = [:]
    @Published var myProfile: Profile?
    @Published var hasSubmittedProfile: Bool = false
    @Published var lastEvent: String = "idle"

    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.profileKey),
           let saved = try? JSONDecoder().decode(Profile.self, from: data) {
            myProfile = saved
        }
    }

    var bothProfilesSubmitted: Bool {
        guard hasSubmittedProfile, !peerIds.isEmpty else { return false }
        return peerIds.allSatisfy { peerProfiles[$0] != nil }
    }

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
        peerProfiles = [:]
        openSocket(sessionId: id)
    }

    func disconnect() {
        cleanupSocket()
        sessionId = nil
        myId = nil
        peerIds = []
        peerProfiles = [:]
        hasSubmittedProfile = false
        state = .idle
    }

    func submitProfile(_ profile: Profile) {
        myProfile = profile
        hasSubmittedProfile = true
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileKey)
        }
        sendProfileOverSocket(profile)
    }

    func shareLinkURL() -> URL? {
        guard let id = sessionId else { return nil }
        return URL(string: "forge://session/\(id.uuidString)")
    }

    private func cleanupSocket() {
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
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
        case .welcome(let yourId, let peers):
            myId = yourId
            peerIds = peers.map(\.peerId)
            peerProfiles = Dictionary(uniqueKeysWithValues: peers.compactMap { peer in
                peer.profile.map { (peer.peerId, $0) }
            })
            state = peerIds.isEmpty ? .waitingForPeer : .connected
            lastEvent = "welcome peers=\(peers.count) profiles=\(peerProfiles.count)"
            if hasSubmittedProfile, let profile = myProfile {
                sendProfileOverSocket(profile)
                lastEvent += " + resent profile"
            }

        case .peerJoined(let peerId):
            if !peerIds.contains(peerId) {
                peerIds.append(peerId)
            }
            state = .connected
            lastEvent = "peerJoined \(peerId.uuidString.prefix(8))"

        case .peerLeft(let peerId):
            peerIds.removeAll { $0 == peerId }
            peerProfiles.removeValue(forKey: peerId)
            state = peerIds.isEmpty ? .waitingForPeer : .connected
            lastEvent = "peerLeft \(peerId.uuidString.prefix(8))"

        case .peerProfileUpdated(let peerId, let profile):
            peerProfiles[peerId] = profile
            lastEvent = "peerProfile \(profile.name) from \(peerId.uuidString.prefix(8))"

        case .sessionFull:
            state = .error("Session is full (2 participants max)")
            task?.cancel(with: .goingAway, reason: nil)
            lastEvent = "sessionFull"
        }
    }

    private func sendProfileOverSocket(_ profile: Profile) {
        let message = ClientMessage.profileUpdate(profile)
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else {
            lastEvent = "send: encode failed"
            return
        }
        guard let task = task else {
            lastEvent = "send: no task (\(text.count) chars lost)"
            return
        }
        let size = text.count
        Task { [weak self] in
            do {
                try await task.send(.string(text))
                await MainActor.run { self?.lastEvent = "sent profileUpdate (\(size) chars)" }
            } catch {
                await MainActor.run { self?.lastEvent = "send failed: \(error.localizedDescription)" }
            }
        }
    }
}
