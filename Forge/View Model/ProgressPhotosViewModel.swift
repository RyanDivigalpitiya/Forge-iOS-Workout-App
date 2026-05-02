import Foundation
import UIKit

enum ProgressPhotoPose: String, CaseIterable, Identifiable {
    case front, side, back
    var id: Self { self }
    var label: String {
        switch self {
        case .front: return "Front"
        case .side: return "Side"
        case .back: return "Back"
        }
    }
}

class ProgressPhotosViewModel: ObservableObject {

    @Published var entries: [ProgressPhotoEntry]

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let storageKey = "progressPhotoEntries"
    private let maxImageSide: CGFloat = 1600
    private let jpegQuality: CGFloat = 0.85

    /// Application Support/ProgressPhotos. Created on init if missing.
    let photosDirectory: URL

    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        photosDirectory: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        if let dir = photosDirectory {
            self.photosDirectory = dir
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.photosDirectory = appSupport.appendingPathComponent("ProgressPhotos", isDirectory: true)
        }
        self.entries = []
        ensureDirectoryExists()
        self.entries = loadEntries()
    }

    init(
        mockEntries entries: [ProgressPhotoEntry],
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        photosDirectory: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        if let dir = photosDirectory {
            self.photosDirectory = dir
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.photosDirectory = appSupport.appendingPathComponent("ProgressPhotos", isDirectory: true)
        }
        self.entries = entries.sorted(by: { $0.date > $1.date })
        ensureDirectoryExists()
    }

    // MARK: - Mutation

    /// Resizes + JPEG-encodes each non-nil pose, writes to disk, persists
    /// metadata to UserDefaults, prepends entry. Returns the inserted entry.
    @discardableResult
    func addEntry(
        date: Date = Date(),
        front: UIImage?,
        side: UIImage?,
        back: UIImage?
    ) -> ProgressPhotoEntry? {
        let frontFilename = persist(image: front)
        let sideFilename = persist(image: side)
        let backFilename = persist(image: back)
        let entry = ProgressPhotoEntry(
            date: date,
            frontFilename: frontFilename,
            sideFilename: sideFilename,
            backFilename: backFilename
        )
        guard entry.hasAnyPhoto else { return nil }
        entries.append(entry)
        entries.sort(by: { $0.date > $1.date })
        saveMetadata()
        return entry
    }

    func deleteEntry(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        for filename in [entry.frontFilename, entry.sideFilename, entry.backFilename].compactMap({ $0 }) {
            try? fileManager.removeItem(at: photosDirectory.appendingPathComponent(filename))
        }
        entries.removeAll(where: { $0.id == id })
        saveMetadata()
    }

    // MARK: - Read

    func loadImage(filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func filename(for entry: ProgressPhotoEntry, pose: ProgressPhotoPose) -> String? {
        switch pose {
        case .front: return entry.frontFilename
        case .side: return entry.sideFilename
        case .back: return entry.backFilename
        }
    }

    func presentPoses(for entry: ProgressPhotoEntry) -> [ProgressPhotoPose] {
        ProgressPhotoPose.allCases.filter { filename(for: entry, pose: $0) != nil }
    }

    // MARK: - Internals

    private func persist(image: UIImage?) -> String? {
        guard let image else { return nil }
        let resized = resizeImage(image, maxSide: maxImageSide)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func ensureDirectoryExists() {
        guard !fileManager.fileExists(atPath: photosDirectory.path) else { return }
        try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }
}

extension ProgressPhotosViewModel {

    func loadEntries() -> [ProgressPhotoEntry] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        guard let decoded = try? JSONDecoder().decode([ProgressPhotoEntry].self, from: data) else { return [] }
        return decoded.sorted(by: { $0.date > $1.date })
    }

    func saveMetadata() {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }
}
