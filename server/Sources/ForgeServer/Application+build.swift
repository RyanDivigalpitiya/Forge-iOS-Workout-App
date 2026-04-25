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

        let myId = UUID()
        let (stream, continuation) = AsyncStream<ServerMessage>.makeStream()

        let addResult = await manager.addParticipant(
            sessionId: sessionId,
            participantId: myId,
            continuation: continuation
        )

        switch addResult {
        case .sessionFull:
            if let data = try? encoder.encode(ServerMessage.sessionFull),
               let text = String(data: data, encoding: .utf8) {
                try? await outbound.write(.text(text))
            }
            return
        case .added(let existingPeers, let suggestedPlan, let workoutInProgress):
            let welcome = ServerMessage.welcome(
                yourId: myId,
                peers: existingPeers,
                suggestedPlan: suggestedPlan,
                workoutInProgress: workoutInProgress
            )
            if let data = try? encoder.encode(welcome),
               let text = String(data: data, encoding: .utf8) {
                try? await outbound.write(.text(text))
            }
            await manager.broadcast(.peerJoined(peerId: myId), in: sessionId, except: myId)

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
                            }
                        }
                    } catch {
                        // Client disconnected — fall through to cleanup.
                    }
                    continuation.finish()
                }
            }

            await manager.removeParticipant(sessionId: sessionId, participantId: myId)
            await manager.broadcast(.peerLeft(peerId: myId), in: sessionId)
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
