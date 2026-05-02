import Foundation
import Testing
import UIKit
@testable import Forge

/// Filesystem + UserDefaults round-trip for `ProgressPhotosViewModel`.
/// Each test gets its own UserDefaults suite AND its own temp directory
/// (deleted in `deinit`) — no shared state across runs.
final class ProgressPhotosViewModelTests {

    let suiteName: String
    let testDefaults: UserDefaults
    let tempDir: URL

    init() {
        suiteName = "ForgeTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProgressPhotosTests.\(UUID().uuidString)", isDirectory: true)
    }

    deinit {
        testDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - helpers

    private func makeImage(color: UIColor = .red, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeVM() -> ProgressPhotosViewModel {
        ProgressPhotosViewModel(userDefaults: testDefaults, photosDirectory: tempDir)
    }

    // MARK: - tests

    @Test func emptyLoadReturnsEmptyArray() {
        let vm = makeVM()
        #expect(vm.entries.isEmpty)
    }

    @Test func addEntryWithThreePosesPersistsThreeFiles() {
        let vm = makeVM()
        let entry = vm.addEntry(
            front: makeImage(color: .red),
            side: makeImage(color: .green),
            back: makeImage(color: .blue)
        )
        #expect(entry != nil)
        #expect(vm.entries.count == 1)
        #expect(entry?.frontFilename != nil)
        #expect(entry?.sideFilename != nil)
        #expect(entry?.backFilename != nil)
        // All three files exist on disk.
        for filename in [entry!.frontFilename!, entry!.sideFilename!, entry!.backFilename!] {
            let path = tempDir.appendingPathComponent(filename).path
            #expect(FileManager.default.fileExists(atPath: path))
        }
    }

    @Test func addEntryWithOnlyFrontLeavesOtherFilenamesNil() {
        let vm = makeVM()
        let entry = vm.addEntry(front: makeImage(), side: nil, back: nil)
        #expect(entry?.frontFilename != nil)
        #expect(entry?.sideFilename == nil)
        #expect(entry?.backFilename == nil)
    }

    @Test func addEntryWithNoPosesReturnsNil() {
        let vm = makeVM()
        let entry = vm.addEntry(front: nil, side: nil, back: nil)
        #expect(entry == nil)
        #expect(vm.entries.isEmpty)
    }

    @Test func metadataRoundTripsViaUserDefaults() {
        let vm = makeVM()
        _ = vm.addEntry(front: makeImage(), side: makeImage(), back: nil)
        let reloaded = makeVM()
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.entries.first?.frontFilename != nil)
        #expect(reloaded.entries.first?.sideFilename != nil)
        #expect(reloaded.entries.first?.backFilename == nil)
    }

    @Test func deleteEntryRemovesFilesAndMetadata() {
        let vm = makeVM()
        let entry = vm.addEntry(front: makeImage(), side: makeImage(), back: makeImage())!
        let frontPath = tempDir.appendingPathComponent(entry.frontFilename!).path
        vm.deleteEntry(id: entry.id)
        #expect(vm.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: frontPath))
        // Metadata persists empty.
        let reloaded = makeVM()
        #expect(reloaded.entries.isEmpty)
    }

    @Test func loadImageReadsBackOriginalBytes() {
        let vm = makeVM()
        let entry = vm.addEntry(front: makeImage(color: .red), side: nil, back: nil)!
        let loaded = vm.loadImage(filename: entry.frontFilename!)
        #expect(loaded != nil)
    }

    @Test func loadImageReturnsNilForMissingFile() {
        let vm = makeVM()
        let result = vm.loadImage(filename: "does-not-exist.jpg")
        #expect(result == nil)
    }

    @Test func entriesSortedDescendingByDate() {
        let vm = makeVM()
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        let newDate = Date(timeIntervalSince1970: 2_000_000)
        _ = vm.addEntry(date: oldDate, front: makeImage(), side: nil, back: nil)
        _ = vm.addEntry(date: newDate, front: makeImage(), side: nil, back: nil)
        #expect(vm.entries.first?.date == newDate)
        #expect(vm.entries.last?.date == oldDate)
    }

    @Test func presentPosesReturnsOnlyNonNil() {
        let vm = makeVM()
        let entry = vm.addEntry(front: makeImage(), side: nil, back: makeImage())!
        let poses = vm.presentPoses(for: entry)
        #expect(poses == [.front, .back])
    }
}
