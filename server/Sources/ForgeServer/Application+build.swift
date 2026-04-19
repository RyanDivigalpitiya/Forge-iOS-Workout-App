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

    let router = Router()
    router.add(middleware: LogRequestsMiddleware(.info))

    router.get("/") { _, _ -> String in
        "ForgeServer online"
    }

    router.post("/sessions") { _, _ -> [String: String] in
        let id = await manager.createSession()
        return ["sessionId": id.uuidString]
    }

    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.add(middleware: LogRequestsMiddleware(.info))

    wsRouter.ws("sessions/:id") { request, context in
        guard let idString = context.parameters.get("id"),
              let id = UUID(uuidString: idString),
              await manager.sessionExists(id)
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
        case .sessionNotFound:
            return
        case .sessionFull:
            if let data = try? encoder.encode(ServerMessage.sessionFull),
               let text = String(data: data, encoding: .utf8) {
                try? await outbound.write(.text(text))
            }
            return
        case .added(let existingPeers):
            let welcome = ServerMessage.welcome(yourId: myId, existingPeers: existingPeers)
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
                        for try await _ in inbound.messages(maxSize: 64_000) {
                            // Stage 1: client sends nothing yet.
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
            configuration: .init(extensions: [.perMessageDeflate()])
        ),
        configuration: .init(address: .hostname(hostname, port: port)),
        logger: logger
    )
}
