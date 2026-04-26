import Foundation
import Hummingbird
import HummingbirdWebSocket
import HummingbirdWSCompression
import Logging

func buildApplication(hostname: String, port: Int) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "ForgeServer")
    logger.logLevel = .info

    let manager = SessionManager.shared
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let router = Router()
    router.add(middleware: LogRequestsMiddleware(.info))

    router.get("/") { _, _ -> String in
        "ForgeServer online"
    }

    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.add(middleware: LogRequestsMiddleware(.info))

    wsRouter.ws("sessions/:id") { _, context in
        guard let idString = context.parameters.get("id"),
              UUID(uuidString: idString) != nil
        else {
            return .dontUpgrade
        }
        return .upgrade([:])
    } onUpgrade: { inbound, outbound, context in
        guard let idString = context.request.uri.path.split(separator: "/").last,
              let sessionId = UUID(uuidString: String(idString))
        else {
            return
        }

        // Parse the stable participant ID from the WS URL's query string.
        // Format: `wss://host/sessions/<sid>?participantId=<pid>`. Falls
        // back to a fresh UUID for backwards compatibility with older
        // iOS clients that don't yet send the param (lets us deploy the
        // server first, then ship the client update).
        let myId: UUID = {
            guard let query = context.request.uri.query else { return UUID() }
            for part in query.split(separator: "&") {
                let kv = part.split(separator: "=", maxSplits: 1)
                guard kv.count == 2, kv[0] == "participantId" else { continue }
                if let id = UUID(uuidString: String(kv[1])) {
                    return id
                }
            }
            return UUID()
        }()

        let (stream, continuation) = AsyncStream<ServerMessage>.makeStream()

        let addResult = await manager.addParticipant(
            sessionId: sessionId,
            participantId: myId,
            continuation: continuation
        )

        // Resolve the welcome payload + the "I'm here" announcement that
        // gets broadcast to existing peers. `.added` is the fresh-slot
        // path → peerJoined. `.rebound` is the reconnect-into-away-slot
        // path → peerReturned (lighter signal: the peer's state on the
        // other side is intact, just the away indicator clears).
        let welcomePeers: [PeerInfo]
        let welcomeSuggestedPlan: PlanSnapshot?
        let welcomeWorkoutInProgress: PlanSnapshot?
        let announcement: ServerMessage

        switch addResult {
        case .sessionFull:
            if let data = try? encoder.encode(ServerMessage.sessionFull),
               let text = String(data: data, encoding: .utf8) {
                try? await outbound.write(.text(text))
            }
            return
        case .added(let existingPeers, let suggestedPlan, let workoutInProgress):
            welcomePeers = existingPeers
            welcomeSuggestedPlan = suggestedPlan
            welcomeWorkoutInProgress = workoutInProgress
            announcement = .peerJoined(peerId: myId)
        case .rebound(let existingPeers, let suggestedPlan, let workoutInProgress):
            welcomePeers = existingPeers
            welcomeSuggestedPlan = suggestedPlan
            welcomeWorkoutInProgress = workoutInProgress
            announcement = .peerReturned(peerId: myId)
        }

        do {
            let welcome = ServerMessage.welcome(
                yourId: myId,
                peers: welcomePeers,
                suggestedPlan: welcomeSuggestedPlan,
                workoutInProgress: welcomeWorkoutInProgress
            )
            if let data = try? encoder.encode(welcome),
               let text = String(data: data, encoding: .utf8) {
                try? await outbound.write(.text(text))
            }
            await manager.broadcast(announcement, in: sessionId, except: myId)

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await message in stream {
                        guard let data = try? encoder.encode(message),
                              let text = String(data: data, encoding: .utf8)
                        else { continue }
                        try? await outbound.write(.text(text))
                    }
                }
                group.addTask {
                    do {
                        for try await frame in inbound.messages(maxSize: 256 * 1024) {
                            guard case .text(let text) = frame,
                                  let data = text.data(using: .utf8),
                                  let message = try? decoder.decode(ClientMessage.self, from: data)
                            else { continue }
                            switch message {
                            case .profileUpdate(let profile):
                                await manager.updateProfile(
                                    sessionId: sessionId,
                                    participantId: myId,
                                    profile: profile
                                )
                                await manager.broadcast(
                                    .peerProfileUpdated(peerId: myId, profile: profile),
                                    in: sessionId,
                                    except: myId
                                )
                            case .suggestPlan(let plan):
                                await manager.updateSuggestedPlan(
                                    sessionId: sessionId,
                                    plan: plan
                                )
                                await manager.broadcast(
                                    .planSuggested(peerId: myId, plan: plan),
                                    in: sessionId,
                                    except: myId
                                )
                            case .sendChat(let text):
                                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { continue }
                                await manager.broadcast(
                                    .peerChat(peerId: myId, text: trimmed, timestamp: Date()),
                                    in: sessionId,
                                    except: myId
                                )
                            case .setReady(let isReady):
                                let shouldStart = await manager.setReady(
                                    sessionId: sessionId,
                                    participantId: myId,
                                    isReady: isReady
                                )
                                await manager.broadcast(
                                    .peerReadyChanged(peerId: myId, isReady: isReady),
                                    in: sessionId,
                                    except: myId
                                )
                                if shouldStart {
                                    await manager.broadcast(
                                        .startWorkout,
                                        in: sessionId,
                                        except: nil
                                    )
                                }
                            case .setCompletion(let exerciseId, let setIndex, let completed):
                                await manager.broadcast(
                                    .peerSetCompletion(
                                        peerId: myId,
                                        exerciseId: exerciseId,
                                        setIndex: setIndex,
                                        completed: completed
                                    ),
                                    in: sessionId,
                                    except: myId
                                )
                            case .positionUpdate(let exerciseIndex, let setIndex, let isResting):
                                await manager.broadcast(
                                    .peerPositionUpdated(
                                        peerId: myId,
                                        exerciseIndex: exerciseIndex,
                                        setIndex: setIndex,
                                        isResting: isResting
                                    ),
                                    in: sessionId,
                                    except: myId
                                )
                            case .breakTimerUpdate(let endDate, let exerciseIndex, let setIndex):
                                await manager.broadcast(
                                    .peerBreakTimerChanged(
                                        peerId: myId,
                                        endDate: endDate,
                                        exerciseIndex: exerciseIndex,
                                        setIndex: setIndex
                                    ),
                                    in: sessionId,
                                    except: myId
                                )
                            case .setWorkoutInProgress(let plan):
                                await manager.setWorkoutInProgress(
                                    sessionId: sessionId,
                                    plan: plan
                                )
                            case .profileSubmitted:
                                await manager.broadcast(
                                    .peerProfileSubmitted(peerId: myId),
                                    in: sessionId,
                                    except: myId
                                )
                            case .workoutFinished:
                                // Clear workoutInProgress so any re-joiner
                                // doesn't get auto-routed back into a
                                // now-orphaned workout, then broadcast
                                // peerFinished so the still-working peer
                                // can show a "Friend finished" banner
                                // before the finisher's WS closes.
                                await manager.setWorkoutInProgress(
                                    sessionId: sessionId,
                                    plan: nil
                                )
                                await manager.broadcast(
                                    .peerFinished(peerId: myId),
                                    in: sessionId,
                                    except: myId
                                )
                            case .workoutCancelled:
                                await manager.setWorkoutInProgress(
                                    sessionId: sessionId,
                                    plan: nil
                                )
                                await manager.broadcast(
                                    .peerCancelled(peerId: myId),
                                    in: sessionId,
                                    except: myId
                                )
                            case .goingBackground:
                                // Mark slot as away + start the 5-min hold.
                                // Other peer sees `peerAway` (subtle UI),
                                // not `peerLeft`. iOS typically kills the
                                // WS within ~5s after this; the cleanup
                                // path below detects the .away state and
                                // skips removeParticipant so the slot
                                // persists for the timeout / a reconnect.
                                let changed = await manager.markAway(
                                    sessionId: sessionId,
                                    participantId: myId
                                )
                                if changed {
                                    await manager.broadcast(
                                        .peerAway(peerId: myId),
                                        in: sessionId,
                                        except: myId
                                    )
                                    await manager.scheduleAwayTimeout(
                                        sessionId: sessionId,
                                        participantId: myId,
                                        duration: .seconds(300)
                                    ) {
                                        // 5 min elapsed without a return —
                                        // promote to a real disconnect.
                                        await manager.removeParticipant(
                                            sessionId: sessionId,
                                            participantId: myId
                                        )
                                        await manager.broadcast(
                                            .peerLeft(peerId: myId),
                                            in: sessionId
                                        )
                                    }
                                }
                            case .returningToForeground:
                                // Defensive fallback: WS survived a brief
                                // background blip without dying, so no
                                // reconnect rebind happened. Flip back to
                                // .connected and tell the other peer.
                                let changed = await manager.markReturned(
                                    sessionId: sessionId,
                                    participantId: myId
                                )
                                if changed {
                                    await manager.broadcast(
                                        .peerReturned(peerId: myId),
                                        in: sessionId,
                                        except: myId
                                    )
                                }
                            }
                        }
                    } catch {
                        // Client disconnected — fall through to cleanup.
                    }
                    continuation.finish()
                }
            }

            // Away-aware cleanup: if the slot was already `.away` when the
            // WS died (typical post-`goingBackground` path on iOS), DON'T
            // remove the participant — the scheduled timeout owns
            // eventual cleanup, and a reconnect-into-away-slot will
            // rebind the continuation. Broadcasts to this peer's now-
            // finished continuation are silently dropped by AsyncStream
            // until the rebind. For all other paths (clean exit, force-
            // quit, network drop, crash) — fire `peerLeft` as before.
            let priorState = await manager.participantState(
                sessionId: sessionId,
                participantId: myId
            )
            switch priorState {
            case .away:
                break
            case .connected, .none:
                await manager.removeParticipant(sessionId: sessionId, participantId: myId)
                await manager.broadcast(.peerLeft(peerId: myId), in: sessionId)
            }
        }
    }

    return Application(
        router: router,
        server: .http1WebSocketUpgrade(
            webSocketRouter: wsRouter,
            configuration: .init(
                maxFrameSize: 1 << 20,
                extensions: [.perMessageDeflate()]
            )
        ),
        configuration: .init(address: .hostname(hostname, port: port)),
        logger: logger
    )
}
