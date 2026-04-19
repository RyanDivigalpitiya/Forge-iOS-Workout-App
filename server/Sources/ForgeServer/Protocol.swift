import Foundation

struct Profile: Codable, Sendable, Equatable {
    var name: String
    var photoData: Data?
}

struct PeerInfo: Codable, Sendable, Equatable {
    let peerId: UUID
    let profile: Profile?
}

enum ServerMessage: Codable, Sendable {
    case welcome(yourId: UUID, peers: [PeerInfo])
    case peerJoined(peerId: UUID)
    case peerLeft(peerId: UUID)
    case peerProfileUpdated(peerId: UUID, profile: Profile)
    case sessionFull
}

enum ClientMessage: Codable, Sendable {
    case profileUpdate(Profile)
}
