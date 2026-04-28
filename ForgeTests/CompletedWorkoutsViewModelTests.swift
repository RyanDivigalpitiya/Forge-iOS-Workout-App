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

    // MARK: - Progress series (Phase B)

    /// Builds a `CompletedWorkout` with the given completion date and an
    /// exercise list described as `[(UUID, [(weight, reps, completed)])]`.
    /// Keeps test bodies focused on the assertion, not the construction.
    private func makeWorkout(
        date: Date,
        exercises: [(UUID, [(weight: Float, reps: Int, completed: Bool)])]
    ) -> CompletedWorkout {
        let exercises = exercises.map { (exId, sets) -> Exercise in
            let setObjs = sets.map {
                Forge.Set(weight: $0.weight, reps: $0.reps, tillFailure: false, completed: $0.completed)
            }
            var ex = Exercise(name: "Bench Press", sets: setObjs)
            ex.id = exId
            return ex
        }
        let plan = WorkoutPlan(name: "Test Plan", exercises: exercises)
        return CompletedWorkout(
            date: date,
            workout: plan,
            elapsedTime: 0,
            completion: "100%"
        )
    }

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    @Test func progressSeriesIncludesAllWorkoutsContainingExercise() {
        let exId = UUID()
        let workouts = [
            makeWorkout(date: date(daysAgo: 10), exercises: [(exId, [(weight: 100, reps: 10, completed: true)])]),
            makeWorkout(date: date(daysAgo: 5),  exercises: [(exId, [(weight: 110, reps: 8,  completed: true)])])
        ]
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: workouts, userDefaults: testDefaults)

        let series = vm.progressSeries(forExerciseId: exId, metric: .weight)
        #expect(series.count == 2)
        // Sorted ascending by date — older value first.
        #expect(series[0].value == 100)
        #expect(series[1].value == 110)
    }

    @Test func progressSeriesIgnoresWorkoutsWithoutExerciseUuid() {
        let exA = UUID()
        let exB = UUID()
        let workout = makeWorkout(
            date: date(daysAgo: 1),
            exercises: [(exA, [(weight: 100, reps: 10, completed: true)])]
        )
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        #expect(vm.progressSeries(forExerciseId: exB, metric: .weight).isEmpty)
    }

    @Test func progressSeriesUsesMaxValueForHeterogeneousSets() {
        let exId = UUID()
        let workout = makeWorkout(date: date(daysAgo: 1), exercises: [(exId, [
            (weight: 100, reps: 10, completed: true),
            (weight: 120, reps: 6,  completed: true),
            (weight: 80,  reps: 12, completed: true),
        ])])
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        #expect(vm.progressSeries(forExerciseId: exId, metric: .weight).first?.value == 120)
        #expect(vm.progressSeries(forExerciseId: exId, metric: .reps).first?.value == 12)
    }

    @Test func progressSeriesIgnoresIncompleteSets() {
        let exId = UUID()
        let workout = makeWorkout(date: date(daysAgo: 1), exercises: [(exId, [
            // Skipped — should not raise the max.
            (weight: 200, reps: 8,  completed: false),
            (weight: 100, reps: 10, completed: true),
        ])])
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        let series = vm.progressSeries(forExerciseId: exId, metric: .weight)
        #expect(series.first?.value == 100)
    }

    @Test func progressSeriesDropsWorkoutsWithExerciseButNoCompletedSets() {
        // Exercise was logged in the workout but every set was skipped —
        // the workout should be omitted entirely, not graphed as zero.
        let exId = UUID()
        let workout = makeWorkout(date: date(daysAgo: 1), exercises: [(exId, [
            (weight: 100, reps: 10, completed: false),
        ])])
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        #expect(vm.progressSeries(forExerciseId: exId, metric: .weight).isEmpty)
    }

    // MARK: - PRs

    @Test func weightPRReturnsHighestWeightedCompletedSet() {
        let exId = UUID()
        let workout = makeWorkout(date: date(daysAgo: 1), exercises: [(exId, [
            (weight: 100, reps: 10, completed: true),
            (weight: 150, reps: 5,  completed: true),
            // Heaviest set, but not completed → must be ignored.
            (weight: 200, reps: 3,  completed: false),
        ])])
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        let pr = vm.weightPR(forExerciseId: exId)
        #expect(pr?.weight == 150)
        #expect(pr?.reps == 5)
    }

    @Test func repsPRReturnsHighestRepCompletedSet() {
        let exId = UUID()
        let workout = makeWorkout(date: date(daysAgo: 1), exercises: [(exId, [
            (weight: 100, reps: 10, completed: true),
            (weight: 80,  reps: 15, completed: true),
            // Highest reps, but not completed → must be ignored.
            (weight: 60,  reps: 30, completed: false),
        ])])
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        let pr = vm.repsPR(forExerciseId: exId)
        #expect(pr?.weight == 80)
        #expect(pr?.reps == 15)
    }

    @Test func prsReturnNilWhenNoCompletedSetsAcrossHistory() {
        let exId = UUID()
        let workout = makeWorkout(date: date(daysAgo: 1), exercises: [(exId, [
            (weight: 100, reps: 10, completed: false),
        ])])
        let vm = CompletedWorkoutsViewModel(mockCompletedWorkouts: [workout], userDefaults: testDefaults)

        #expect(vm.weightPR(forExerciseId: exId) == nil)
        #expect(vm.repsPR(forExerciseId: exId) == nil)
    }
}
