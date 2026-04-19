import Hummingbird

let app = try await buildApplication(hostname: "127.0.0.1", port: 8080)
try await app.runService()
