import Foundation
import Testing
@testable import Forge

/// Covers CompletedWorkoutsViewModel's pure formatters, persistence round-trip,
/// and the subtle reverse-index logic in `deleteCompletedWorkouts`.
///
/// `final class` so `deinit` can clean up the isolated UserDefaults suite.
final class CompletedWorkoutsViewModelTests {

    let suiteName: String
    let testDefaults: UserDefaults

    init() {
        suiteName = "ForgeTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - format(timeInterval:)

    @Test func formatTimeIntervalSeconds() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(vm.format(timeInterval: 30) == "30 seconds")
    }

    @Test func formatTimeIntervalZero() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        // 0 seconds hits the `seconds > 1 || seconds == 0` plural branch.
        #expect(vm.format(timeInterval: 0) == "0 seconds")
    }

    @Test func formatTimeIntervalOneSecond() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(vm.format(timeInterval: 1) == "1 second")
    }

    @Test func formatTimeIntervalSingleMinute() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(vm.format(timeInterval: 60) == "1 minute")
    }

    @Test func formatTimeIntervalMultipleMinutes() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(vm.format(timeInterval: 120) == "2 minutes")
    }

    @Test func formatTimeIntervalHoursAndMinutes() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        // 1 hour, 1 minute = 3600 + 60 = 3660s
        #expect(vm.format(timeInterval: 3660) == "1 hour, 1 minute")
    }

    @Test func formatTimeIntervalWholeHours() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        // 2 hours, 0 minutes = 7200s. minutes == 0 takes the "s" branch.
        #expect(vm.format(timeInterval: 7200) == "2 hours, 0 minutes")
    }

    // MARK: - numberOfDaysString(from:)

    @Test func numberOfDaysStringToday() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(vm.numberOfDaysString(from: Date()) == "Today")
    }

    @Test func numberOfDaysStringYesterday() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(vm.numberOfDaysString(from: yesterday) == "Yesterday")
    }

    @Test func numberOfDaysStringThreeDaysAgo() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        #expect(vm.numberOfDaysString(from: threeDaysAgo) == "3 days ago")
    }

    // MARK: - Persistence round-trip

    @Test func saveAndLoadCompletedWorkoutsRoundTrip() {
        // NOTE: testDefaults is isolated per-test via init/deinit.
        let vm = CompletedWorkoutsViewModel(
            mockCompletedWorkouts: mockCompletedWorkouts,
            userDefaults: testDefaults
        )
        vm.saveCompletedWorkouts()

        let reloaded = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(reloaded.completedWorkouts.count == mockCompletedWorkouts.count)
        #expect(reloaded.completedWorkouts.map(\.workout.name) == mockCompletedWorkouts.map(\.workout.name))
    }

    @Test func loadCompletedWorkoutsFromEmptyDefaultsReturnsEmpty() {
        let vm = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(vm.completedWorkouts.isEmpty)
    }

    // MARK: - deleteCompletedWorkouts reverse-index logic

    @Test func deleteCompletedWorkoutsReverseIndexSingleDeletion() {
        // The view shows completed workouts in reverse order, so `offsets` are
        // indices into the REVERSED array. `actualIndices = count - 1 - offset`.
        //
        // With 3 workouts [A, B, C] (storage order), the view displays [C, B, A].
        // Deleting display-index 0 → actualIndex = 3 - 1 - 0 = 2 → removes C.
        // Remaining storage order: [A, B].
        let vm = CompletedWorkoutsViewModel(
            mockCompletedWorkouts: mockCompletedWorkouts,
            userDefaults: testDefaults
        )
        let originalNames = vm.completedWorkouts.map(\.workout.name)

        vm.deleteCompletedWorkouts(at: IndexSet(integer: 0))

        // The last element of the ORIGINAL storage order should be gone.
        #expect(vm.completedWorkouts.count == 2)
        #expect(vm.completedWorkouts.map(\.workout.name) == Array(originalNames.prefix(2)))
    }

    @Test func deleteCompletedWorkoutsReverseIndexLastDisplayItem() {
        // Deleting display-index 2 (the "oldest" at the bottom of the list)
        // → actualIndex = 3 - 1 - 2 = 0 → removes storage index 0.
        // Remaining storage order: [B, C].
        let vm = CompletedWorkoutsViewModel(
            mockCompletedWorkouts: mockCompletedWorkouts,
            userDefaults: testDefaults
        )
        let originalNames = vm.completedWorkouts.map(\.workout.name)

        vm.deleteCompletedWorkouts(at: IndexSet(integer: 2))

        #expect(vm.completedWorkouts.count == 2)
        #expect(vm.completedWorkouts.map(\.workout.name) == Array(originalNames.suffix(2)))
    }

    @Test func deleteCompletedWorkoutsPersistsAfterDelete() {
        let vm = CompletedWorkoutsViewModel(
            mockCompletedWorkouts: mockCompletedWorkouts,
            userDefaults: testDefaults
        )
        vm.saveCompletedWorkouts()
        vm.deleteCompletedWorkouts(at: IndexSet(integer: 0))

        let reloaded = CompletedWorkoutsViewModel(userDefaults: testDefaults)
        #expect(reloaded.completedWorkouts.count == 2)
    }
}
