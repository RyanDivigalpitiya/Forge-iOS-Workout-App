import Foundation
import Testing
@testable import Forge

/// Covers `BodyWeightViewModel` persistence + mutation, and the
/// `WeightUnit` lb↔kg conversion + formatting helpers.
final class BodyWeightViewModelTests {

    let suiteName: String
    let testDefaults: UserDefaults

    init() {
        suiteName = "ForgeTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - persistence

    @Test func emptyLoadReturnsEmptyArray() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        #expect(vm.entries.isEmpty)
    }

    @Test func saveThenReloadRoundTrips() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        vm.addEntry(weightLbs: 175.0, date: Date(timeIntervalSince1970: 1_700_000_000))
        vm.addEntry(weightLbs: 173.5, date: Date(timeIntervalSince1970: 1_700_500_000))
        let reloaded = BodyWeightViewModel(userDefaults: testDefaults)
        #expect(reloaded.entries.count == 2)
        #expect(reloaded.entries.contains { $0.weightLbs == 175.0 })
        #expect(reloaded.entries.contains { $0.weightLbs == 173.5 })
    }

    // MARK: - sorting

    @Test func addEntrySortsDescendingByDate() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        let oldest = Date(timeIntervalSince1970: 1_000_000)
        let middle = Date(timeIntervalSince1970: 2_000_000)
        let newest = Date(timeIntervalSince1970: 3_000_000)
        vm.addEntry(weightLbs: 160, date: middle)
        vm.addEntry(weightLbs: 165, date: oldest)
        vm.addEntry(weightLbs: 158, date: newest)
        #expect(vm.entries.map { $0.date } == [newest, middle, oldest])
    }

    // MARK: - delete

    @Test func deleteEntryRemovesById() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        let a = vm.addEntry(weightLbs: 170)
        _ = vm.addEntry(weightLbs: 171)
        vm.deleteEntry(id: a.id)
        #expect(vm.entries.count == 1)
        #expect(!vm.entries.contains(where: { $0.id == a.id }))
    }

    @Test func deleteEntryPersistsToUserDefaults() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        let a = vm.addEntry(weightLbs: 170)
        vm.deleteEntry(id: a.id)
        let reloaded = BodyWeightViewModel(userDefaults: testDefaults)
        #expect(reloaded.entries.isEmpty)
    }

    // MARK: - net difference

    @Test func netDifferencePositiveGain() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        let earlier = BodyWeightEntry(date: Date(timeIntervalSince1970: 100), weightLbs: 160)
        let later = BodyWeightEntry(date: Date(timeIntervalSince1970: 200), weightLbs: 162.5)
        #expect(vm.netDifference(from: earlier, to: later) == 2.5)
    }

    @Test func netDifferenceNegativeLoss() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        let earlier = BodyWeightEntry(date: Date(timeIntervalSince1970: 100), weightLbs: 160)
        let later = BodyWeightEntry(date: Date(timeIntervalSince1970: 200), weightLbs: 158)
        #expect(vm.netDifference(from: earlier, to: later) == -2)
    }

    @Test func netDifferenceZero() {
        let vm = BodyWeightViewModel(userDefaults: testDefaults)
        let earlier = BodyWeightEntry(date: Date(timeIntervalSince1970: 100), weightLbs: 160)
        let later = BodyWeightEntry(date: Date(timeIntervalSince1970: 200), weightLbs: 160)
        #expect(vm.netDifference(from: earlier, to: later) == 0)
    }

    // MARK: - WeightUnit

    @Test func lbsToKgZero() {
        #expect(WeightUnit.lbsToKg(0) == 0)
    }

    @Test func lbsToKg220IsApprox100() {
        let kg = WeightUnit.lbsToKg(220.46226218)
        #expect(abs(kg - 100) < 0.001)
    }

    @Test func formatLbsWholeNumber() {
        #expect(WeightUnit.formatLbs(160) == "160 lb")
    }

    @Test func formatLbsHalfStep() {
        #expect(WeightUnit.formatLbs(160.5) == "160.5 lb")
    }

    @Test func formatKgRoundsToOneDecimal() {
        // 160 lb ≈ 72.57 kg → "72.6 kg"
        #expect(WeightUnit.formatKg(160) == "72.6 kg")
    }
}
