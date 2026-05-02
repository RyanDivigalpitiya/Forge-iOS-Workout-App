import Foundation

struct ProgressPhotoEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var frontFilename: String?
    var sideFilename: String?
    var backFilename: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        frontFilename: String? = nil,
        sideFilename: String? = nil,
        backFilename: String? = nil
    ) {
        self.id = id
        self.date = date
        self.frontFilename = frontFilename
        self.sideFilename = sideFilename
        self.backFilename = backFilename
    }

    var hasAnyPhoto: Bool {
        frontFilename != nil || sideFilename != nil || backFilename != nil
    }
}
