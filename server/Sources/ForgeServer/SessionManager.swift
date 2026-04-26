import Foundation

actor SessionManager {
    static let shared = SessionManager()

    static let capacity = 2

    /// A participant's connection state. `.away` means the iOS app is
    /// backgrounded — the WebSocket may already be dead, but the slot is
    /// held alive for up to 5 minutes so a quick app-switch + reconnect
    /// rebinds to the same slot (preserving profile, ready flag, peer
    /// identity from the other client's POV) instead of looking like a
    /// disconnect+rejoin. See `markAway` / `scheduleAwayTimeout`.
    enum ParticipantState: Sendable {
        case connected
        case away(since: Date)
    }

    private final class Session {
        let id: UUID
        struct ParticipantInfo {
            // `var` (not `let`) so a reconnect can rebind a fresh
            // continuation onto the existing away slot — see
            // `addParticipant`'s `.rebound` path.
            var continuation: AsyncStream<ServerMessage>.Continuation
            var profile: Profile?
            var isReady: Bool = false
            var state: ParticipantState = .connected
            /// Handle to the 5-min timeout scheduled by `scheduleAwayTimeout`.
            /// Cancelled when the participant returns (rebind or explicit
            /// `markReturned`) or when the slot is removed.
            var awayTimeout: Task<Void, Never>? = nil
        }
        var participants: [UUID: ParticipantInfo] = [:]
        var suggestedPlan: PlanSnapshot?
        // Set when setReady triggers a startWorkout broadcast; persists for
        // the lifetime of the session so a phone that disconnects mid-
        // workout and re-joins can be routed straight back into the active
        // workout instead of the plan-suggestion screen. Cleared implicitly
        // when the session is deleted (last participant leaves).
        var workoutInProgress: PlanSnapshot?
        init(id: UUID) { self.id = id }
    }

    private var sessions: [UUID: Session] = [:]

    enum AddResult {
        /// Fresh slot created (or first peer in a new session). Caller
        /// should broadcast `peerJoined`.
        case added(existingPeers: [PeerInfo], suggestedPlan: PlanSnapshot?, workoutInProgress: PlanSnapshot?)
        /// Reconnect-into-away-slot: same participantId existed in an
        /// `.away` slot. The continuation has been rebound, the away
        /// timeout cancelled, profile/ready preserved. Caller should
        /// broadcast `peerReturned` (NOT `peerJoined`).
        case rebound(existingPeers: [PeerInfo], suggestedPlan: PlanSnapshot?, workoutInProgress: PlanSnapshot?)
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

        // Reconnect-into-away-slot path: same participantId exists, in
        // .away state. Rebind the continuation, cancel the timeout, flip
        // back to .connected. Profile + ready flag persist across the
        // rebind so the other peer sees no state churn.
        if var existing = session.participants[participantId], case .away = existing.state {
            existing.awayTimeout?.cancel()
            existing.awayTimeout = nil
            existing.state = .connected
            existing.continuation = continuation
            session.participants[participantId] = existing
            let existingPeers: [PeerInfo] = session.participants
                .filter { $0.key != participantId }
                .map { pid, info in PeerInfo(peerId: pid, profile: info.profile) }
            return .rebound(
                existingPeers: existingPeers,
                suggestedPlan: session.suggestedPlan,
                workoutInProgress: session.workoutInProgress
            )
        }

        if session.participants.count >= Self.capacity { return .sessionFull }
        let existingPeers: [PeerInfo] = session.participants.map { pid, info in
            PeerInfo(peerId: pid, profile: info.profile)
        }
        session.participants[participantId] = Session.ParticipantInfo(
            continuation: continuation,
            profile: nil
        )
        return .added(
            existingPeers: existingPeers,
            suggestedPlan: session.suggestedPlan,
            workoutInProgress: session.workoutInProgress
        )
    }

    /// Marks the session as having a workout actively in progress with the
    /// given plan snapshot. Called after setReady's all-ready transition
    /// triggers a startWorkout broadcast, so a phone that disconnects and
    /// re-joins can be re-routed straight to the workout view.
    func setWorkoutInProgress(sessionId: UUID, plan: PlanSnapshot?) {
        sessions[sessionId]?.workoutInProgress = plan
    }

    func removeParticipant(sessionId: UUID, participantId: UUID) {
        guard let session = sessions[sessionId] else { return }
        if let info = session.participants[participantId] {
            info.awayTimeout?.cancel()
        }
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

    /// Updates the participant's ready flag. Returns true if this update
    /// just made everyone in the session ready — the caller should
    /// broadcast `.startWorkout` to all participants. Workout entry is
    /// immediate; the WorkoutInProgressView already has its own 3-second
    /// starting countdown, so the collab layer doesn't add one.
    /// Side effect: when this transition fires, the session's
    /// workoutInProgress is set to the current suggestedPlan so future
    /// re-joiners can be routed straight back into the active workout.
    func setReady(sessionId: UUID, participantId: UUID, isReady: Bool) -> Bool {
        guard let session = sessions[sessionId] else { return false }
        guard var info = session.participants[participantId] else { return false }
        let wasAllReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        info.isReady = isReady
        session.participants[participantId] = info
        let nowAllReady = session.participants.count >= Self.capacity
            && session.participants.values.allSatisfy(\.isReady)
        let justStarted = nowAllReady && !wasAllReady
        if justStarted {
            session.workoutInProgress = session.suggestedPlan
        }
        return justStarted
    }

    func broadcast(_ message: ServerMessage, in sessionId: UUID, except exceptId: UUID? = nil) {
        guard let session = sessions[sessionId] else { return }
        for (pid, info) in session.participants where pid != exceptId {
            info.continuation.yield(message)
        }
    }

    /// Flips the participant to `.away`. Returns true if state changed
    /// (= caller should broadcast `peerAway` and call `scheduleAwayTimeout`).
    /// Returns false if already away — guards against double-broadcast on
    /// repeat `goingBackground` messages.
    func markAway(sessionId: UUID, participantId: UUID) -> Bool {
        guard let session = sessions[sessionId] else { return false }
        guard var info = session.participants[participantId] else { return false }
        if case .away = info.state { return false }
        info.state = .away(since: Date())
        info.awayTimeout?.cancel()
        info.awayTimeout = nil
        session.participants[participantId] = info
        return true
    }

    /// Flips the participant back to `.connected`. Returns true if state
    /// changed (= caller should broadcast `peerReturned`).
    func markReturned(sessionId: UUID, participantId: UUID) -> Bool {
        guard let session = sessions[sessionId] else { return false }
        guard var info = session.participants[participantId] else { return false }
        if case .connected = info.state { return false }
        info.state = .connected
        info.awayTimeout?.cancel()
        info.awayTimeout = nil
        session.participants[participantId] = info
        return true
    }

    func participantState(sessionId: UUID, participantId: UUID) -> ParticipantState? {
        sessions[sessionId]?.participants[participantId]?.state
    }

    /// Schedules a timeout that fires `onTimeout` after `duration`. If the
    /// participant returns (rebind or explicit `markReturned`) before the
    /// timeout fires, the task is cancelled. Re-entry replaces any prior
    /// pending task. The closure is called outside the actor — re-enter
    /// the manager from inside if needed (typical: removeParticipant +
    /// broadcast peerLeft).
    func scheduleAwayTimeout(
        sessionId: UUID,
        participantId: UUID,
        duration: Duration,
        onTimeout: @Sendable @escaping () async -> Void
    ) {
        guard let session = sessions[sessionId] else { return }
        guard var info = session.participants[participantId] else { return }
        info.awayTimeout?.cancel()
        let task = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await onTimeout()
        }
        info.awayTimeout = task
        session.participants[participantId] = info
    }
}
