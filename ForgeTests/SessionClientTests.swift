import Foundation
import Testing
@testable import Forge

/// Covers SessionClient's wire-message handler. Each test encodes a
/// ServerMessage, feeds the JSON string through `handle(incoming:)` —
/// exactly what readLoop does after a WebSocket frame arrives — and
/// asserts on the post-handler `@Published` state. No URLSession, no
/// task mocking, no backoff timing. Pure state-mutation coverage.
///
/// Class is `@MainActor` because SessionClient is `@MainActor` — init
/// and every property access must hop onto the main actor.
@MainActor
final class SessionClientTests {

    let client: SessionClient

    init() {
        client = SessionClient()
    }

    // MARK: - Helpers

    /// Encodes a ServerMessage through the same JSONEncoder path the real
    /// server uses, then feeds the resulting UTF-8 string into the handler.
    /// Using the round-trip encoder keeps tests honest — if the enum's
    /// Codable representation ever shifts, every test fails loudly.
    private func send(_ message: ServerMessage) {
        let data = try! JSONEncoder().encode(message)
        let text = String(data: data, encoding: .utf8)!
        client.handle(incoming: text)
    }

    // MARK: - welcome

    @Test func welcomeWithPeersTransitionsToConnected() {
        let myId = UUID()
        let peerId = UUID()
        let profile = Profile(name: "Alex", photoData: nil)

        send(.welcome(
            yourId: myId,
            peers: [PeerInfo(peerId: peerId, profile: profile)],
            suggestedPlan: nil,
            workoutInProgress: nil
        ))

        #expect(client.myId == myId)
        #expect(client.peerIds == [peerId])
        #expect(client.peerProfiles[peerId] == profile)
        #expect(client.isPaired)
    }

    @Test func welcomeWithNoPeersStaysWaitingForPeer() {
        send(.welcome(
            yourId: UUID(),
            peers: [],
            suggestedPlan: nil,
            workoutInProgress: nil
        ))

        #expect(client.peerIds.isEmpty)
        #expect(client.state == .waitingForPeer)
    }

    @Test func welcomeFiltersPeersWithNilProfile() {
        // A peer who hasn't yet submitted their profile appears in peerIds
        // but must NOT get an entry in peerProfiles. UI reads the absence
        // to render a placeholder until peerProfileUpdated arrives.
        let withProfile = PeerInfo(
            peerId: UUID(),
            profile: Profile(name: "A", photoData: nil)
        )
        let withoutProfile = PeerInfo(peerId: UUID(), profile: nil)

        send(.welcome(
            yourId: UUID(),
            peers: [withProfile, withoutProfile],
            suggestedPlan: nil,
            workoutInProgress: nil
        ))

        #expect(client.peerIds.count == 2)
        #expect(client.peerProfiles[withProfile.peerId] != nil)
        #expect(client.peerProfiles[withoutProfile.peerId] == nil)
    }

    @Test func welcomeMirrorsWorkoutInProgress() {
        // Stage 7b' contract: mid-workout rejoiners see workoutInProgress in
        // welcome and auto-route into WorkoutInProgressView with that plan.
        let snapshot = PlanSnapshot(
            id: UUID(),
            name: "Push Day",
            exercises: [
                ExerciseSnapshot(id: UUID(), name: "Bench Press", sets: [
                    SetSnapshot(weight: 135, reps: 8, tillFailure: false)
                ])
            ]
        )

        send(.welcome(
            yourId: UUID(),
            peers: [],
            suggestedPlan: nil,
            workoutInProgress: snapshot
        ))

        #expect(client.workoutInProgress?.id == snapshot.id)
        #expect(client.workoutInProgress?.name == "Push Day")
    }

    // MARK: - peerJoined

    @Test func peerJoinedAppendsAndConnects() {
        let peerId = UUID()
        send(.peerJoined(peerId: peerId))
        #expect(client.peerIds == [peerId])
        #expect(client.isPaired)
    }

    @Test func peerJoinedDoesNotDuplicateOnRepeatBroadcast() {
        // Defensive against message-ordering quirks. Duplicate entries would
        // render double avatars in the gutter and break the ready-up dot row.
        let peerId = UUID()
        send(.peerJoined(peerId: peerId))
        send(.peerJoined(peerId: peerId))
        #expect(client.peerIds == [peerId])
    }

    @Test func peerJoinedPromotesWaitingForPeerToPaired() {
        // State-enum invariant: after a welcome with no peers puts us in
        // .waitingForPeer, the first peerJoined must transition to .paired.
        // Regression guard for the Stage 5 invariant refactor.
        send(.welcome(
            yourId: UUID(),
            peers: [],
            suggestedPlan: nil,
            workoutInProgress: nil
        ))
        #expect(client.state == .waitingForPeer)

        let peerId = UUID()
        send(.peerJoined(peerId: peerId))
        #expect(client.state == .paired(peerIds: [peerId]))
    }

    // MARK: - peerLeft

    @Test func peerLeftClearsAllPerPeerState() {
        // Regression guard for the ghost-"?"-avatar bug. peerLeft must wipe
        // every dict keyed by the leaving UUID; otherwise the UUID persists
        // as a phantom in the gutter / ready row after the peer rejoins
        // with a fresh UUID.
        let peerId = UUID()

        send(.peerJoined(peerId: peerId))
        send(.peerProfileUpdated(
            peerId: peerId,
            profile: Profile(name: "A", photoData: nil)
        ))
        send(.peerPositionUpdated(
            peerId: peerId,
            exerciseIndex: 0, setIndex: 0, isResting: false
        ))
        send(.peerBreakTimerChanged(
            peerId: peerId,
            endDate: Date().addingTimeInterval(60),
            exerciseIndex: 0, setIndex: 0
        ))
        send(.peerReadyChanged(peerId: peerId, isReady: true))
        send(.peerProfileSubmitted(peerId: peerId))

        #expect(client.peerProfiles[peerId] != nil)
        #expect(client.peerPositions[peerId] != nil)
        #expect(client.peerBreakTimer[peerId] != nil)
        #expect(client.peerReady[peerId] == true)
        #expect(client.peerCommittedProfiles.contains(peerId))

        send(.peerLeft(peerId: peerId))

        #expect(client.peerIds.isEmpty)
        #expect(client.peerProfiles[peerId] == nil)
        #expect(client.peerPositions[peerId] == nil)
        #expect(client.peerBreakTimer[peerId] == nil)
        #expect(client.peerReady[peerId] == nil)
        #expect(client.peerCommittedProfiles.contains(peerId) == false)
        #expect(client.state == .waitingForPeer)
    }

    // MARK: - peerProfileUpdated

    @Test func peerProfileUpdatedStoresProfile() {
        let peerId = UUID()
        let profile = Profile(name: "Alex", photoData: Data([0x01, 0x02]))
        // Handler requires the peerId to be in peerIds — simulate the prior
        // peerJoined broadcast.
        send(.peerJoined(peerId: peerId))
        send(.peerProfileUpdated(peerId: peerId, profile: profile))
        #expect(client.peerProfiles[peerId] == profile)
    }

    @Test func peerProfileUpdatedIgnoresUnknownPeerId() {
        // Out-of-order delivery: profileUpdated arrives after peerLeft (or
        // before peerJoined). Must not leave a phantom entry keyed by a UUID
        // we don't recognise.
        let unknown = UUID()
        send(.peerProfileUpdated(
            peerId: unknown,
            profile: Profile(name: "Ghost", photoData: nil)
        ))
        #expect(client.peerProfiles[unknown] == nil)
    }

    // MARK: - peerSetCompletion

    @Test func peerSetCompletionAddThenRemove() {
        let exerciseId = UUID()
        let key = PeerSetKey(exerciseId: exerciseId, setIndex: 1)

        send(.peerSetCompletion(
            peerId: UUID(), exerciseId: exerciseId,
            setIndex: 1, completed: true
        ))
        #expect(client.peerCompletedSets.contains(key))

        send(.peerSetCompletion(
            peerId: UUID(), exerciseId: exerciseId,
            setIndex: 1, completed: false
        ))
        #expect(!client.peerCompletedSets.contains(key))
    }

    // MARK: - peerPositionUpdated

    @Test func peerPositionUpdatedStoresPosition() {
        let peerId = UUID()
        send(.peerPositionUpdated(
            peerId: peerId,
            exerciseIndex: 2, setIndex: 3, isResting: true
        ))
        #expect(client.peerPositions[peerId] == UserPosition(
            exerciseIndex: 2, setIndex: 3, isResting: true
        ))
    }

    // MARK: - peerBreakTimerChanged

    @Test func peerBreakTimerChangedSetAndClear() {
        let peerId = UUID()
        let endDate = Date().addingTimeInterval(60)

        send(.peerBreakTimerChanged(
            peerId: peerId, endDate: endDate,
            exerciseIndex: 0, setIndex: 1
        ))
        #expect(client.peerBreakTimer[peerId]?.setIndex == 1)
        #expect(client.peerBreakTimer[peerId]?.exerciseIndex == 0)

        // Nil endDate clears the entry (dismiss / natural expiry).
        send(.peerBreakTimerChanged(
            peerId: peerId, endDate: nil,
            exerciseIndex: 0, setIndex: 1
        ))
        #expect(client.peerBreakTimer[peerId] == nil)
    }

    // MARK: - peerChat

    @Test func peerChatAppendsWithIsMineFalse() {
        send(.peerChat(peerId: UUID(), text: "hey", timestamp: Date()))
        #expect(client.chatEntries.count == 1)
        #expect(client.chatEntries.first?.text == "hey")
        #expect(client.chatEntries.first?.isMine == false)
    }

    // MARK: - peerReadyChanged

    @Test func peerReadyChangedStoresFlag() {
        let peerId = UUID()
        send(.peerReadyChanged(peerId: peerId, isReady: true))
        #expect(client.peerReady[peerId] == true)

        send(.peerReadyChanged(peerId: peerId, isReady: false))
        #expect(client.peerReady[peerId] == false)
    }

    // MARK: - startWorkout

    @Test func startWorkoutEmitsFreshSignalEachTime() {
        // Signal is a UUID? that changes on every .startWorkout — lets the
        // PlanSuggestionView .onChange re-fire without a manual reset step
        // between rounds.
        #expect(client.startWorkoutSignal == nil)

        send(.startWorkout)
        let firstSignal = client.startWorkoutSignal
        #expect(firstSignal != nil)

        send(.startWorkout)
        #expect(client.startWorkoutSignal != firstSignal)
    }

    // MARK: - sessionFull

    @Test func sessionFullTransitionsToErrorState() {
        send(.sessionFull)
        if case .error(let message) = client.state {
            #expect(message.lowercased().contains("full"))
        } else {
            Issue.record("Expected .error state, got \(client.state)")
        }
    }

    // MARK: - ClientMessage protocol symmetry

    @Test func profileSubmittedClientMessageRoundTrips() {
        // Wire-protocol guard for the explicit-commit signal that gates
        // bothProfilesSubmitted nav. No payload — purely a flag flip on
        // the receiver side.
        let message = ClientMessage.profileSubmitted
        let data = try! JSONEncoder().encode(message)
        let decoded = try! JSONDecoder().decode(ClientMessage.self, from: data)
        if case .profileSubmitted = decoded {
            // Round-tripped correctly.
        } else {
            Issue.record("Expected .profileSubmitted, got \(decoded)")
        }
    }

    @Test func peerProfileSubmittedFlipsCommittedSet() {
        // peerProfileSubmitted should insert the peer into
        // peerCommittedProfiles, gated on peerIds.contains. Untracked peers
        // are silently ignored (out-of-order or post-peerLeft delivery).
        let peerId = UUID()
        send(.peerJoined(peerId: peerId))
        #expect(client.peerCommittedProfiles.contains(peerId) == false)

        send(.peerProfileSubmitted(peerId: peerId))
        #expect(client.peerCommittedProfiles.contains(peerId))
    }

    @Test func peerProfileSubmittedIgnoredForUnknownPeerId() {
        let unknown = UUID()
        send(.peerProfileSubmitted(peerId: unknown))
        #expect(client.peerCommittedProfiles.contains(unknown) == false)
    }

    @Test func setWorkoutInProgressClientMessageRoundTrips() {
        // Outbound protocol guard: solo → joint share flow relies on
        // .setWorkoutInProgress encoding/decoding identically on both sides
        // of the socket. If the enum case ever drifts (reorder, rename,
        // associated-value change), this fails loudly before manual smoke.
        let snapshot = PlanSnapshot(
            id: UUID(),
            name: "Push Day",
            exercises: [
                ExerciseSnapshot(id: UUID(), name: "Bench Press", sets: [
                    SetSnapshot(weight: 135, reps: 8, tillFailure: false)
                ])
            ]
        )
        let message = ClientMessage.setWorkoutInProgress(snapshot)

        let data = try! JSONEncoder().encode(message)
        let decoded = try! JSONDecoder().decode(ClientMessage.self, from: data)

        if case .setWorkoutInProgress(let roundTripped) = decoded {
            #expect(roundTripped?.id == snapshot.id)
            #expect(roundTripped?.name == "Push Day")
            #expect(roundTripped?.exercises.count == 1)
        } else {
            Issue.record("Expected .setWorkoutInProgress, got \(decoded)")
        }

        // Nil payload is the "clear workoutInProgress" signal — must survive
        // the round trip without collapsing into some other case.
        let clearMessage = ClientMessage.setWorkoutInProgress(nil)
        let clearData = try! JSONEncoder().encode(clearMessage)
        let clearDecoded = try! JSONDecoder().decode(ClientMessage.self, from: clearData)
        if case .setWorkoutInProgress(let plan) = clearDecoded {
            #expect(plan == nil)
        } else {
            Issue.record("Expected .setWorkoutInProgress(nil), got \(clearDecoded)")
        }
    }
}
