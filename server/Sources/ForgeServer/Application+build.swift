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
        case .added(let existingPeers):
            let welcome = ServerMessage.welcome(yourId: myId, peers: existingPeers)
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
                            guard case .text(let text) = frame else {
                                logger.info("[\(myId)] non-text frame ignored")
                                continue
                            }
                            logger.info("[\(myId)] received text frame (\(text.count) chars)")
                            guard let data = text.data(using: .utf8) else {
                                logger.info("[\(myId)] could not utf8-decode frame")
                                continue
                            }
                            let message: ClientMessage
                            do {
                                message = try decoder.decode(ClientMessage.self, from: data)
                            } catch {
                                logger.info("[\(myId)] failed to decode ClientMessage: \(error)")
                                continue
                            }
                            switch message {
                            case .profileUpdate(let profile):
                                logger.info("[\(myId)] profileUpdate name=\(profile.name) photo=\(profile.photoData?.count ?? 0) bytes")
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
                                logger.info("[\(myId)] broadcasted peerProfileUpdated to session \(sessionId)")
                            }
                        }
                    } catch {
                        logger.info("[\(myId)] inbound loop ended with error: \(error)")
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
            configuration: .init(extensions: [.perMessageDeflate()])
        ),
        configuration: .init(address: .hostname(hostname, port: port)),
        logger: logger
    )
}
