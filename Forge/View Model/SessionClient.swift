import Foundation
import Combine
import SwiftUI

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
    case welcome(yourId: UUID, peers: [PeerInfo], suggestedPlan: PlanSnapshot?, workoutInProgress: PlanSnapshot?)
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case planSuggested(peerId: UUID, plan: PlanSnapshot)
    case peerChat(peerId: UUID, text: String, timestamp: Date)
    case peerReadyChanged(peerId: UUID, isReady: Bool)
    case startWorkout
    case peerSetCompletion(peerId: UUID, exerciseId: UUID, setIndex: Int, completed: Bool)
    case peerPositionUpdated(peerId: UUID, exerciseIndex: Int, setIndex: Int, isResting: Bool)
    case peerBreakTimerChanged(peerId: UUID, endDate: Date?, exerciseIndex: Int, setIndex: Int)
    case peerProfileSubmitted(peerId: UUID)
    case sessionFull
}

enum ClientMessage: Codable {
    case profileUpdate(Profile)
    case suggestPlan(PlanSnapshot)
    case sendChat(text: String)
    case setReady(isReady: Bool)
    case setCompletion(exerciseId: UUID, setIndex: Int, completed: Bool)
    case positionUpdate(exerciseIndex: Int, setIndex: Int, isResting: Bool)
    case breakTimerUpdate(endDate: Date?, exerciseIndex: Int, setIndex: Int)
    /// Host-only write for the solo → joint promotion flow. Sent right
    /// after `createSession()` when the user taps Share from an active
    /// solo workout. Mirrors server-side `ClientMessage.setWorkoutInProgress`.
    case setWorkoutInProgress(PlanSnapshot?)
    /// Sent when the user explicitly taps "Join Session →" in
    /// JoinSessionView. Distinct from `.profileUpdate` (which fires on
    /// every in-progress edit) so peers can differentiate "still
    /// entering" from "committed". Mirrors server-side
    /// `ClientMessage.profileSubmitted`.
    case profileSubmitted
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

/// A peer's currently-running break timer. Stored in SessionClient's
/// peerBreakTimer dict only while the peer is actively resting; removed
/// when they dismiss or the break expires server-side.
struct PeerBreakTimer: Equatable {
    let endDate: Date
    let exerciseIndex: Int
    let setIndex: Int
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

    /// Session lifecycle. `.paired` carries peerIds directly so the "connected
    /// without peers" illegal state is unrepresentable — any socket-up /
    /// peer-present assertion in the view layer becomes a pattern match over
    /// this case instead of a cross-check between two independent fields.
    enum State: Equatable {
        case idle
        case connecting
        case waitingForPeer                   // socket up, no peer yet
        case paired(peerIds: [UUID])          // socket up, peer(s) present
        case disconnected(reason: String)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var sessionId: UUID?
    @Published var myId: UUID?
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
    /// UUIDs of peers who have explicitly tapped "Join Session →"
    /// (server-broadcast `peerProfileSubmitted`). Tracked separately from
    /// `peerProfiles` so live-edit `peerProfileUpdated` broadcasts don't
    /// prematurely satisfy the bothProfilesSubmitted nav gate. Cleared
    /// on disconnect/reconnect; entries removed on peerLeft.
    @Published var peerCommittedProfiles: Swift.Set<UUID> = []
    @Published var peerPositions: [UUID: UserPosition] = [:]
    @Published var peerBreakTimer: [UUID: PeerBreakTimer] = [:]
    /// Set in the welcome handler when the server reports an active workout
    /// for this session. Drives the auto-route into WorkoutInProgressView
    /// for re-joiners. Cleared on disconnect; the server clears its copy
    /// only when the session itself is deleted (last participant leaves).
    @Published var workoutInProgress: PlanSnapshot? = nil

    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectScheduler: Task<Void, Never>?
    private var reconnectAttempt: Int = 0
    private var cancellables: Swift.Set<AnyCancellable> = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.profileKey),
           let saved = try? JSONDecoder().decode(Profile.self, from: data) {
            myProfile = saved
        }

        // Diagnostic + auto-reconnect: log every state transition (intermittent
        // joint-mode UI disappearance needs a trail), and when state lands on
        // .disconnected with an active session, schedule a reconnect with
        // exponential backoff. didSet on @Published breaks objectWillChange
        // (see CLAUDE.md), so we pair (previous, current) via Combine.
        $state
            .zip($state.dropFirst())
            .sink { [weak self] old, new in
                Log.debug("[SessionClient] state: \(old) → \(new) @ \(Date())")
                guard let self else { return }
                if case .disconnected = new, self.sessionId != nil {
                    self.scheduleReconnect()
                }
            }
            .store(in: &cancellables)
    }

    /// Current paired peer UUIDs, or an empty array in any non-paired state.
    /// Reads as a derived view of `state` — Swift won't auto-track the
    /// dependency, but `@Published var state` already publishes on every
    /// transition, so SwiftUI invalidation via `@EnvironmentObject` still
    /// re-evaluates any view that reads this accessor.
    var peerIds: [UUID] {
        if case .paired(let ids) = state { return ids }
        return []
    }

    /// True whenever the session is actively paired (socket up + peer present).
    /// Preferred over `state == .paired(peerIds: ...)` at call sites that
    /// don't need the peer list — pattern-matching a `case .paired` arm only
    /// is also fine.
    var isPaired: Bool {
        if case .paired = state { return true }
        return false
    }

    var bothProfilesSubmitted: Bool {
        guard hasSubmittedProfile, !peerIds.isEmpty else { return false }
        return peerIds.allSatisfy { peerCommittedProfiles.contains($0) }
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

    /// Host-side entry point for the solo → joint promotion flow. Creates a
    /// fresh session and immediately registers `workoutInProgress` server-side
    /// so any peer who joins via the shared URL auto-routes into
    /// `WorkoutInProgressView` (via the Stage 7b' welcome path). Messages
    /// buffer on the URLSessionWebSocketTask if the socket isn't fully open
    /// yet, so no await gymnastics needed — the task flushes them as soon as
    /// the upgrade completes, well before any peer can tap the link, navigate,
    /// submit profile, and connect.
    ///
    /// `myProfile` is preserved in memory across `createSession()`'s
    /// `disconnect()`, but `hasSubmittedProfile` gets cleared. We re-flag it
    /// here + re-send so the new session carries the host's name/photo
    /// without an extra user action.
    func startSharedSessionForActiveWorkout(plan: WorkoutPlan) {
        createSession()
        sendClientMessage(.setWorkoutInProgress(PlanSnapshot(from: plan)))
        if let profile = myProfile {
            hasSubmittedProfile = true
            sendClientMessage(.profileUpdate(profile))
        }
    }

    func reconnect() {
        guard let id = sessionId else { return }
        guard case .disconnected = state else { return }
        cleanupSocket()
        myId = nil
        peerProfiles = [:]
        // Joint-mode side state was keyed by the OLD peer UUIDs and the OLD
        // myId. After reconnect everyone gets fresh UUIDs, so any leftover
        // entries become stale phantoms (e.g., the avatar gutter renders one
        // ghost "?" avatar per stale peerPositions key). Clear them so the
        // first peerPositionUpdated / peerSetCompletion / peerBreakTimerChanged
        // after reconnect repopulates from scratch.
        peerReady = [:]
        peerCompletedSets = []
        peerPositions = [:]
        peerBreakTimer = [:]
        peerCommittedProfiles = []
        openSocket(sessionId: id)
    }

    func disconnect() {
        reconnectScheduler?.cancel()
        reconnectScheduler = nil
        reconnectAttempt = 0
        cleanupSocket()
        sessionId = nil
        myId = nil
        peerProfiles = [:]
        hasSubmittedProfile = false
        suggestedPlan = nil
        chatEntries = []
        myIsReady = false
        peerReady = [:]
        startWorkoutSignal = nil
        peerCompletedSets = []
        peerPositions = [:]
        peerBreakTimer = [:]
        peerCommittedProfiles = []
        workoutInProgress = nil
        state = .idle
    }

    func submitProfile(_ profile: Profile) {
        myProfile = profile
        hasSubmittedProfile = true
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileKey)
        }
        sendProfileOverSocket(profile)
        // Distinct commit signal — peers gate auto-nav on this, not on
        // .profileUpdate (which fires for every in-progress edit too).
        sendClientMessage(.profileSubmitted)
    }

    /// Live-broadcast variant of `submitProfile`. Updates `myProfile` and
    /// the UserDefaults cache, sends a `profileUpdate` to the server (which
    /// re-broadcasts to peers as `peerProfileUpdated`) — but DOESN'T touch
    /// `hasSubmittedProfile`. Use this for in-progress edits in
    /// JoinSessionView so the peer sees the user's name/photo live without
    /// the form locking or the navigation-to-PlanSuggestionView gate
    /// firing on the local user's side. The explicit "Join Session →"
    /// button still calls `submitProfile`, which is what trips the gate.
    func updateProfile(_ profile: Profile) {
        myProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileKey)
        }
        sendProfileOverSocket(profile)
    }

    /// Wipes the locally-cached collab profile (name + photo) from memory
    /// and UserDefaults, and resets `hasSubmittedProfile` so any future
    /// JoinSessionView appearance will show the form for re-entry rather
    /// than auto-submitting a stale profile. Doesn't broadcast anything
    /// to the server — peers retain whatever profile they last received
    /// for this user until the user submits a new one.
    func clearProfile() {
        myProfile = nil
        hasSubmittedProfile = false
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
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

    /// Broadcasts this phone's break-timer state. `endDate: nil` signals the
    /// timer just ended (dismiss or natural expiry); a non-nil endDate
    /// signals a fresh break starting. `exerciseIndex` / `setIndex` identify
    /// which set the peer was resting after, so the other phone can render
    /// the indicator next to the right row.
    func sendBreakTimerUpdate(endDate: Date?, exerciseIndex: Int, setIndex: Int) {
        sendClientMessage(
            .breakTimerUpdate(
                endDate: endDate,
                exerciseIndex: exerciseIndex,
                setIndex: setIndex
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
        pingTask?.cancel()
        pingTask = nil
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
        pingTask = Task { [weak self] in
            await self?.pingLoop(task: newTask)
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

    /// Sends an application-level WebSocket ping every 30s to keep the
    /// connection alive across NAT/Cloudflare idle timeouts and to surface
    /// dead sockets quickly. A failed pong cancels the underlying task,
    /// which causes readLoop's `task.receive()` to throw → state goes to
    /// .disconnected → the Combine state sink schedules an auto-reconnect.
    private func pingLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                task.sendPing { error in
                    if let error {
                        Log.debug("[SessionClient] ping failed: \(error.localizedDescription)")
                        task.cancel(with: .abnormalClosure, reason: nil)
                    }
                    cont.resume()
                }
            }
        }
    }

    /// Exponential-backoff auto-reconnect. Runs after the state sink sees
    /// a transition into .disconnected with an active session. Caps at 32s
    /// so a long-down server doesn't get hammered. Resets on a successful
    /// .welcome response.
    private func scheduleReconnect() {
        reconnectScheduler?.cancel()
        reconnectAttempt += 1
        let delaySeconds = min(pow(2.0, Double(reconnectAttempt)), 32.0)
        Log.debug("[SessionClient] scheduling reconnect attempt \(reconnectAttempt) in \(delaySeconds)s")
        reconnectScheduler = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard case .disconnected = self.state else { return }
            self.reconnect()
        }
    }

    /// Parses a server-side wire frame and mutates `@Published` state. Package-
    /// internal rather than private so `ForgeTests/SessionClientTests` can feed
    /// synthetic messages in without going through the WebSocket.
    func handle(incoming text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data)
        else { return }

        switch message {
        case .welcome(let yourId, let peers, let suggested, let inProgress):
            myId = yourId
            let incomingPeerIds = peers.map(\.peerId)
            peerProfiles = Dictionary(uniqueKeysWithValues: peers.compactMap { peer in
                peer.profile.map { (peer.peerId, $0) }
            })
            suggestedPlan = suggested
            workoutInProgress = inProgress
            state = incomingPeerIds.isEmpty ? .waitingForPeer : .paired(peerIds: incomingPeerIds)
            // Successful welcome — reset the backoff counter so any future
            // disconnect starts the next cycle from a 2s delay, not picking
            // up where the last cycle left off.
            reconnectAttempt = 0
            if hasSubmittedProfile, let profile = myProfile {
                sendProfileOverSocket(profile)
                // Re-broadcast our committed status so peers (post-reconnect
                // or already-in-session-when-we-arrived) know to flip our
                // committed flag without a fresh tap-Join-Session.
                sendClientMessage(.profileSubmitted)
            }

        case .peerJoined(let peerId):
            var updated = peerIds
            if !updated.contains(peerId) {
                updated.append(peerId)
            }
            state = .paired(peerIds: updated)
            // The new peer's welcome carries existing peers' profiles but
            // NOT their committed state (server doesn't track it). Re-send
            // our commit signal so they flip our entry in their
            // peerCommittedProfiles set.
            if hasSubmittedProfile {
                sendClientMessage(.profileSubmitted)
            }

        case .peerLeft(let peerId):
            peerProfiles.removeValue(forKey: peerId)
            // Mirror the reconnect() cleanup — wipe per-peer side state
            // keyed by the leaving UUID so it doesn't linger as a ghost
            // when (or if) the peer rejoins with a fresh UUID.
            peerPositions.removeValue(forKey: peerId)
            peerBreakTimer.removeValue(forKey: peerId)
            peerReady.removeValue(forKey: peerId)
            peerCommittedProfiles.remove(peerId)
            let remaining = peerIds.filter { $0 != peerId }
            state = remaining.isEmpty ? .waitingForPeer : .paired(peerIds: remaining)

        case .peerProfileUpdated(let peerId, let profile):
            // Ignore profile updates for peerIds we don't recognise — guards
            // against out-of-order delivery (profileUpdated after peerLeft)
            // leaving orphaned entries in peerProfiles.
            guard peerIds.contains(peerId) else { return }
            peerProfiles[peerId] = profile

        case .peerProfileSubmitted(let peerId):
            // Same out-of-order guard as peerProfileUpdated.
            guard peerIds.contains(peerId) else { return }
            peerCommittedProfiles.insert(peerId)

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
            withAnimation(.easeInOut(duration: 0.25)) {
                peerPositions[peerId] = UserPosition(
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex,
                    isResting: isResting
                )
            }

        case .peerBreakTimerChanged(let peerId, let endDate, let exerciseIndex, let setIndex):
            if let endDate {
                peerBreakTimer[peerId] = PeerBreakTimer(
                    endDate: endDate,
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex
                )
            } else {
                peerBreakTimer.removeValue(forKey: peerId)
            }

        case .sessionFull:
            state = .error("Session is full (2 participants max)")
            task?.cancel(with: .goingAway, reason: nil)
        }
    }

    private func sendProfileOverSocket(_ profile: Profile) {
        sendClientMessage(.profileUpdate(profile))
    }

    /// Fail-loud outbound send. Encode failures log and drop (shouldn't happen
    /// — every ClientMessage case is Codable — but surfacing catches future
    /// protocol-change regressions). A nil task logs the drop so the developer
    /// sees messages going into the void during local races. A send error
    /// cancels the task with .abnormalClosure, which trips readLoop's catch
    /// path → state becomes .disconnected → auto-reconnect fires. Without
    /// this, a silently-broken socket stays "connected" on our side forever.
    private func sendClientMessage(_ message: ClientMessage) {
        let data: Data
        do {
            data = try JSONEncoder().encode(message)
        } catch {
            Log.debug("[SessionClient] failed to encode outgoing message: \(error)")
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            Log.debug("[SessionClient] failed to convert encoded message to utf8")
            return
        }
        guard let task else {
            Log.debug("[SessionClient] dropped outgoing message — no active task")
            return
        }
        Task {
            do {
                try await task.send(.string(text))
            } catch {
                Log.debug("[SessionClient] send failed: \(error.localizedDescription) — cancelling task")
                task.cancel(with: .abnormalClosure, reason: nil)
            }
        }
    }
}
