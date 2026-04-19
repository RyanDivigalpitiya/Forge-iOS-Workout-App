import Foundation

enum ServerMessage: Codable, Sendable {
    case welcome(yourId: UUID, existingPeers: [UUID])
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case sessionFull
}
