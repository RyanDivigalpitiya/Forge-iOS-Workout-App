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

    // Mirrors PlanViewModel.calculateWorkoutDuration(for:) but operates on the
    // wire snapshot so the Suggested-Workout pane can show duration without
    // having the live WorkoutPlan object.
    var durationMinutes: Int {
        let timeInbetweenSets = 60 * 5
        let breakTime = 60
        let repTime = 3
        let exercisesWithSets = exercises.filter { !$0.sets.isEmpty }
        guard !exercisesWithSets.isEmpty else { return 0 }
        var workoutTime = timeInbetweenSets
        for exercise in exercisesWithSets {
            var exerciseTime = 0
            for set in exercise.sets {
                exerciseTime += set.reps * repTime + breakTime
            }
            workoutTime += exerciseTime + timeInbetweenSets - breakTime
        }
        return workoutTime > 60 ? workoutTime / 60 : 0
    }
}

extension PlanSnapshot {
    // Materialises the wire snapshot into a live WorkoutPlan value type for
    // feeding into PlanEditorView in read-only preview mode. UUIDs are
    // freshly generated — this temporary plan is never inserted into
    // planViewModel.workoutPlans, so identity doesn't need to match the
    // snapshot's ids.
    func toWorkoutPlan() -> WorkoutPlan {
        let mappedExercises: [Exercise] = exercises.map { ex in
            var exercise = Exercise(
                name: ex.name,
                sets: ex.sets.map { s in
                    Set(
                        weight: s.weight,
                        reps: s.reps,
                        tillFailure: s.tillFailure,
                        completed: false
                    )
                }
            )
            // Preserve the wire snapshot's UUID so both phones address the
            // same exercise by the same id during the joint workout (set
            // completion sync in Stage 6a keys off this).
            exercise.id = ex.id
            return exercise
        }
        var plan = WorkoutPlan(name: name, exercises: mappedExercises)
        plan.id = id
        return plan
    }
}

enum ServerMessage: Codable {
    case welcome(yourId: UUID, peers: [PeerInfo], suggestedPlan: PlanSnapshot?)
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case planSuggested(peerId: UUID, plan: PlanSnapshot)
    case peerChat(peerId: UUID, text: String, timestamp: Date)
    case peerReadyChanged(peerId: UUID, isReady: Bool)
    case startWorkout
    case peerSetCompletion(peerId: UUID, exerciseId: UUID, setIndex: Int, completed: Bool)
    case peerPositionUpdated(peerId: UUID, exerciseIndex: Int, setIndex: Int, isResting: Bool)
    case sessionFull
}

enum ClientMessage: Codable {
    case profileUpdate(Profile)
    case suggestPlan(PlanSnapshot)
    case sendChat(text: String)
    case setReady(isReady: Bool)
    case setCompletion(exerciseId: UUID, setIndex: Int, completed: Bool)
    case positionUpdate(exerciseIndex: Int, setIndex: Int, isResting: Bool)
}

/// Identifies a specific set in the joint workout. Used as a Hashable key
/// so SessionClient.peerCompletedSets can be a Swift.Set and SwiftUI views
/// can query membership in O(1) while rendering set rows.
struct PeerSetKey: Hashable, Codable {
    let exerciseId: UUID
    let setIndex: Int
}

/// Where a participant currently is in the joint workout.
/// `isResting` is true when they're on a break timer right after completing
/// the set at (exerciseIndex, setIndex). When false, they're about to do
/// (or are doing) that set.
struct UserPosition: Hashable, Codable {
    let exerciseIndex: Int
    let setIndex: Int
    let isResting: Bool
}

// Local-only — not sent on the wire. Stores an `isMine` flag captured at
// insertion time so renders survive myId changes across reconnects
// (my messages stay "mine" even after the server assigns a fresh UUID).
struct ChatEntry: Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isMine: Bool
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
    @Published var chatEntries: [ChatEntry] = []
    @Published var myIsReady: Bool = false
    @Published var peerReady: [UUID: Bool] = [:]
    /// Changes to a fresh UUID each time the server broadcasts `.startWorkout`
    /// so PlanSuggestionView can fire its navigation via `.onChange` without
    /// needing to manually reset the flag between sessions.
    @Published var startWorkoutSignal: UUID?
    @Published var peerCompletedSets: Swift.Set<PeerSetKey> = []
    @Published var peerPositions: [UUID: UserPosition] = [:]

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
        chatEntries = []
        myIsReady = false
        peerReady = [:]
        startWorkoutSignal = nil
        peerCompletedSets = []
        peerPositions = [:]
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

    func sendChat(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatEntries.append(
            ChatEntry(id: UUID(), text: trimmed, timestamp: Date(), isMine: true)
        )
        sendClientMessage(.sendChat(text: trimmed))
    }

    func toggleReady() {
        setReady(!myIsReady)
    }

    func setReady(_ isReady: Bool) {
        guard myIsReady != isReady else { return }
        myIsReady = isReady
        sendClientMessage(.setReady(isReady: isReady))
    }

    func sendSetCompletion(exerciseId: UUID, setIndex: Int, completed: Bool) {
        sendClientMessage(
            .setCompletion(exerciseId: exerciseId, setIndex: setIndex, completed: completed)
        )
    }

    func sendPositionUpdate(_ position: UserPosition) {
        sendClientMessage(
            .positionUpdate(
                exerciseIndex: position.exerciseIndex,
                setIndex: position.setIndex,
                isResting: position.isResting
            )
        )
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

        case .peerChat(_, let text, let timestamp):
            chatEntries.append(
                ChatEntry(id: UUID(), text: text, timestamp: timestamp, isMine: false)
            )

        case .peerReadyChanged(let peerId, let isReady):
            peerReady[peerId] = isReady

        case .startWorkout:
            startWorkoutSignal = UUID()

        case .peerSetCompletion(_, let exerciseId, let setIndex, let completed):
            let key = PeerSetKey(exerciseId: exerciseId, setIndex: setIndex)
            if completed {
                peerCompletedSets.insert(key)
            } else {
                peerCompletedSets.remove(key)
            }

        case .peerPositionUpdated(let peerId, let exerciseIndex, let setIndex, let isResting):
            peerPositions[peerId] = UserPosition(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                isResting: isResting
            )

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
