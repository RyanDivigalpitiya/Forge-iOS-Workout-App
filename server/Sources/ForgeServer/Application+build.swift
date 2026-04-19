import Hummingbird
import HummingbirdWebSocket
import HummingbirdWSCompression
import Logging

func buildApplication(hostname: String, port: Int) async throws -> some ApplicationProtocol {
    var logger = Logger(label: "ForgeServer")
    logger.logLevel = .info

    let router = Router()
    router.add(middleware: LogRequestsMiddleware(.info))
    router.get("/") { _, _ in "ForgeServer online" }

    let wsRouter = Router(context: BasicWebSocketRequestContext.self)
    wsRouter.add(middleware: LogRequestsMiddleware(.info))
    wsRouter.ws("ping") { _, _ in
        .upgrade([:])
    } onUpgrade: { inbound, outbound, _ in
        for try await frame in inbound {
            guard frame.opcode == .text else { continue }
            let text = String(buffer: frame.data)
            let reply = text == "ping" ? "pong" : "echo: \(text)"
            try await outbound.write(.text(reply))
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
