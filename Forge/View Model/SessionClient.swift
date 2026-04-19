import Foundation

struct Profile: Codable, Equatable {
    var name: String
    var photoData: Data?
}

struct PeerInfo: Codable, Equatable {
    let peerId: UUID
    let profile: Profile?
}

struct SetSnapshot: Codable, Equatable {
    let weight: Float
    let reps: Int
    let tillFailure: Bool
}

struct ExerciseSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let sets: [SetSnapshot]
}

struct PlanSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let exercises: [ExerciseSnapshot]

    init(id: UUID, name: String, exercises: [ExerciseSnapshot]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    init(from plan: WorkoutPlan) {
        self.id = plan.id
        self.name = plan.name
        self.exercises = plan.exercises.map { exercise in
            ExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                sets: exercise.sets.map { set in
                    SetSnapshot(
                        weight: set.weight,
                        reps: set.reps,
                        tillFailure: set.tillFailure
                    )
                }
            )
        }
    }
}

enum ServerMessage: Codable {
    case welcome(yourId: UUID, peers: [PeerInfo], suggestedPlan: PlanSnapshot?)
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case planSuggested(peerId: UUID, plan: PlanSnapshot)
    case sessionFull
}

enum ClientMessage: Codable {
    case profileUpdate(Profile)
    case suggestPlan(PlanSnapshot)
}

@MainActor
final class SessionClient: ObservableObject {

    static let serverHost = "reserve-hiring-vegetables-adsl.trycloudflare.com"
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
    @Published var suggestedPlan: PlanSnapshot?

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
        suggestedPlan = nil
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

    func suggestPlan(from plan: WorkoutPlan) {
        let snapshot = PlanSnapshot(from: plan)
        suggestedPlan = snapshot
        sendClientMessage(.suggestPlan(snapshot))
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
        case .welcome(let yourId, let peers, let suggested):
            myId = yourId
            peerIds = peers.map(\.peerId)
            peerProfiles = Dictionary(uniqueKeysWithValues: peers.compactMap { peer in
                peer.profile.map { (peer.peerId, $0) }
            })
            suggestedPlan = suggested
            state = peerIds.isEmpty ? .waitingForPeer : .connected
            if hasSubmittedProfile, let profile = myProfile {
                sendProfileOverSocket(profile)
            }

        case .peerJoined(let peerId):
            if !peerIds.contains(peerId) {
                peerIds.append(peerId)
            }
            state = .connected

        case .peerLeft(let peerId):
            peerIds.removeAll { $0 == peerId }
            peerProfiles.removeValue(forKey: peerId)
            state = peerIds.isEmpty ? .waitingForPeer : .connected

        case .peerProfileUpdated(let peerId, let profile):
            peerProfiles[peerId] = profile

        case .planSuggested(_, let plan):
            suggestedPlan = plan

        case .sessionFull:
            state = .error("Session is full (2 participants max)")
            task?.cancel(with: .goingAway, reason: nil)
        }
    }

    private func sendProfileOverSocket(_ profile: Profile) {
        sendClientMessage(.profileUpdate(profile))
    }

    private func sendClientMessage(_ message: ClientMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8),
              let task = task
        else { return }
        Task {
            try? await task.send(.string(text))
        }
    }
}
