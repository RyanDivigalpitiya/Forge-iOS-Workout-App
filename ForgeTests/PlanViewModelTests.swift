import Foundation
import Testing
@testable import Forge

/// Covers PlanViewModel's pure functions (`calculateWorkoutDuration`,
/// `isThereNonZeroDecimal`), persistence round-trips via an injected
/// UserDefaults, and the mutation helpers (`movePlan`, `deletePlan`,
/// `moveExercise`, `deleteExercise`).
///
/// This is a `final class` (not `struct`) so `deinit` can clean up the
/// isolated UserDefaults suite after each test. Swift Testing creates a
/// fresh instance per `@Test`, so `init` + `deinit` act like setUp/tearDown.
final class PlanViewModelTests {

    let suiteName: String
    let testDefaults: UserDefaults

    init() {
        suiteName = "ForgeTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - calculateWorkoutDuration

    @Test func calculateWorkoutDurationEmptyPlanReturnsZero() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let plan = WorkoutPlan(name: "Empty", exercises: [])
        #expect(vm.calculateWorkoutDuration(for: plan) == 0)
    }

    @Test func calculateWorkoutDurationExerciseWithNoSetsReturnsZero() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let exercise = Exercise(name: "Empty", sets: [])
        let plan = WorkoutPlan(name: "Only Empty Exercise", exercises: [exercise])
        // Filter removes the exercise → guard triggers → returns 0.
        #expect(vm.calculateWorkoutDuration(for: plan) == 0)
    }

    @Test func calculateWorkoutDurationSingleSetOneExercise() {
        // Algorithm: 300s setup + (12*3 + 60) exerciseTime + 300 - 60
        //           = 300 + 96 + 240 = 636s = 10 min (Int division).
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let set = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
        let exercise = Exercise(name: "Bench", sets: [set])
        let plan = WorkoutPlan(name: "Test", exercises: [exercise])
        #expect(vm.calculateWorkoutDuration(for: plan) == 10)
    }

    @Test func calculateWorkoutDurationThreeSetsOneExercise() {
        // 300 + (3 * (10*3 + 60)) + 300 - 60 = 300 + 270 + 240 = 810s = 13 min.
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let sets = Array(repeating: Set(weight: 100, reps: 10, tillFailure: false, completed: false), count: 3)
        let exercise = Exercise(name: "Squat", sets: sets)
        let plan = WorkoutPlan(name: "Test", exercises: [exercise])
        #expect(vm.calculateWorkoutDuration(for: plan) == 13)
    }

    @Test func calculateWorkoutDurationFiltersEmptyExercises() {
        // A plan with one exercise that has sets and one empty exercise should
        // produce the same result as a plan with just the non-empty exercise.
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let realExercise = Exercise(
            name: "Real",
            sets: [Set(weight: 100, reps: 12, tillFailure: false, completed: false)]
        )
        let emptyExercise = Exercise(name: "Empty", sets: [])

        let fullPlan = WorkoutPlan(name: "Full", exercises: [realExercise, emptyExercise])
        let filteredPlan = WorkoutPlan(name: "Filtered", exercises: [realExercise])

        #expect(vm.calculateWorkoutDuration(for: fullPlan) == vm.calculateWorkoutDuration(for: filteredPlan))
    }

    // MARK: - isThereNonZeroDecimal

    @Test func isThereNonZeroDecimalIntegerValue() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        #expect(vm.isThereNonZeroDecimal(in: 10.0) == "10")
    }

    @Test func isThereNonZeroDecimalHalfValue() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        #expect(vm.isThereNonZeroDecimal(in: 10.5) == "10.5")
    }

    @Test func isThereNonZeroDecimalZero() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        #expect(vm.isThereNonZeroDecimal(in: 0.0) == "0")
    }

    // MARK: - Persistence round-trip

    @Test func saveAndLoadPlansRoundTrip() {
        // NOTE: all persistence tests inject `testDefaults` so they never
        // touch UserDefaults.standard. Fresh per-test suite via init()/deinit().
        let vm = PlanViewModel(mockPlans: mockWorkoutPlans, userDefaults: testDefaults)
        vm.savePlans()

        let reloaded = PlanViewModel(userDefaults: testDefaults)
        #expect(reloaded.workoutPlans.count == mockWorkoutPlans.count)
        #expect(reloaded.workoutPlans.map(\.name) == mockWorkoutPlans.map(\.name))
        #expect(reloaded.workoutPlans.first?.exercises.count == mockWorkoutPlans.first?.exercises.count)
    }

    @Test func loadPlansFromEmptyDefaultsReturnsEmpty() {
        let vm = PlanViewModel(userDefaults: testDefaults)
        #expect(vm.workoutPlans.isEmpty)
    }

    // MARK: - movePlan / deletePlan

    @Test func movePlanReordersAndPersists() {
        let vm = PlanViewModel(mockPlans: mockWorkoutPlans, userDefaults: testDefaults)
        let originalFirstName = vm.workoutPlans[0].name

        // Move index 0 to the end (IndexSet(integer: 0), toOffset: 3).
        vm.movePlan(from: IndexSet(integer: 0), to: 3)

        #expect(vm.workoutPlans.last?.name == originalFirstName)

        // Verify the move persisted via a fresh VM reading the same defaults.
        let reloaded = PlanViewModel(userDefaults: testDefaults)
        #expect(reloaded.workoutPlans.last?.name == originalFirstName)
    }

    @Test func deletePlanRemovesAndPersists() {
        let vm = PlanViewModel(mockPlans: mockWorkoutPlans, userDefaults: testDefaults)
        let originalCount = vm.workoutPlans.count
        let nameToDelete = vm.workoutPlans[1].name

        vm.deletePlan(at: IndexSet(integer: 1))

        #expect(vm.workoutPlans.count == originalCount - 1)
        #expect(vm.workoutPlans.contains(where: { $0.name == nameToDelete }) == false)

        let reloaded = PlanViewModel(userDefaults: testDefaults)
        #expect(reloaded.workoutPlans.count == originalCount - 1)
    }

    // MARK: - moveExercise / deleteExercise

    @Test func moveExerciseReordersActivePlan() {
        let vm = PlanViewModel(mockPlans: mockWorkoutPlans, userDefaults: testDefaults)
        // init(mockPlans:) sets activePlan to mockPlans.first
        let originalFirstName = vm.activePlan.exercises[0].name
        let exerciseCount = vm.activePlan.exercises.count

        vm.moveExercise(from: IndexSet(integer: 0), to: exerciseCount)

        #expect(vm.activePlan.exercises.last?.name == originalFirstName)
    }

    @Test func deleteExerciseRemovesFromActivePlan() {
        let vm = PlanViewModel(mockPlans: mockWorkoutPlans, userDefaults: testDefaults)
        let originalCount = vm.activePlan.exercises.count

        vm.deleteExercise(at: IndexSet(integer: 0))

        #expect(vm.activePlan.exercises.count == originalCount - 1)
    }

    // MARK: - importPlan

    @Test func importPlanStripsCompletionState() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: true),
            Set(weight: 100, reps: 10, tillFailure: false, completed: true),
        ]
        let exercise = Exercise(name: "Bench", sets: sets)
        var plan = WorkoutPlan(name: "Shared", exercises: [exercise])
        plan.lastCompleted = Date()

        vm.importPlan(plan)

        let imported = vm.workoutPlans[0]
        #expect(imported.lastCompleted == nil)
        #expect(imported.exercises[0].sets.allSatisfy { $0.completed == false })
        #expect(imported.exercises[0].completed == false)
    }

    @Test func importPlanSuffixesOnNameCollision() {
        let existing = WorkoutPlan(name: "Push Day", exercises: [])
        let vm = PlanViewModel(mockPlans: [existing], userDefaults: testDefaults)
        let incoming = WorkoutPlan(name: "Push Day", exercises: [])

        vm.importPlan(incoming)
        #expect(vm.workoutPlans.map(\.name) == ["Push Day", "Push Day (Imported)"])

        vm.importPlan(WorkoutPlan(name: "Push Day", exercises: []))
        #expect(vm.workoutPlans.map(\.name).last == "Push Day (Imported) 2")
    }

    @Test func importPlanKeepsOriginalNameWhenNoCollision() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let plan = WorkoutPlan(name: "Leg Day", exercises: [])

        vm.importPlan(plan)

        #expect(vm.workoutPlans.first?.name == "Leg Day")
    }

    @Test func importPlanPersistsAcrossReload() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        vm.importPlan(WorkoutPlan(name: "Shared", exercises: []))

        let reloaded = PlanViewModel(userDefaults: testDefaults)
        #expect(reloaded.workoutPlans.first?.name == "Shared")
    }

    @Test func importPlanPreservesIncomingLineageId() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        var incoming = WorkoutPlan(name: "Shared", exercises: [])
        let originalLineage = UUID()
        incoming.lineageId = originalLineage

        vm.importPlan(incoming)

        #expect(vm.workoutPlans.first?.lineageId == originalLineage)
    }

    @Test func importPlanMintsLineageIdWhenIncomingHasNone() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        var incoming = WorkoutPlan(name: "Shared", exercises: [])
        incoming.lineageId = nil

        vm.importPlan(incoming)

        #expect(vm.workoutPlans.first?.lineageId != nil)
    }

    @Test func importPlanRefreshesFingerprintToMatchSanitizedStructure() {
        let vm = PlanViewModel(mockPlans: [], userDefaults: testDefaults)
        let exercise = Exercise(
            name: "Bench Press",
            sets: [Forge.Set(weight: 100, reps: 10, tillFailure: false, completed: false)]
        )
        let plan = WorkoutPlan(name: "Shared", exercises: [exercise])
        let expectedFingerprint = WorkoutPlan.computeFingerprint(for: [exercise])

        vm.importPlan(plan)

        #expect(vm.workoutPlans.first?.fingerprint == expectedFingerprint)
    }

    // MARK: - Migration (lineageId / fingerprint backfill)

    /// Test-only mirror used to encode plan blobs that lack the new identity
    /// fields, simulating data persisted by an older app version. Decoding
    /// back into the real `WorkoutPlan` (which has optional fields) leaves
    /// both nil — exactly the state the migration handles.
    private struct LegacyPlanBlob: Encodable {
        let id: UUID
        let name: String
        let exercises: [Exercise]
        let lastCompleted: Date?
    }

    private func seedLegacyPlans(_ plans: [LegacyPlanBlob]) {
        let data = try! JSONEncoder().encode(plans)
        testDefaults.set(data, forKey: "workoutPlans")
    }

    @Test func migrationBackfillsLineageIdAndFingerprintOnLoad() {
        let exercise = Exercise(
            name: "Bench Press",
            sets: [Forge.Set(weight: 100, reps: 10, tillFailure: false, completed: false)]
        )
        seedLegacyPlans([
            LegacyPlanBlob(id: UUID(), name: "Push Day", exercises: [exercise], lastCompleted: nil),
            LegacyPlanBlob(id: UUID(), name: "Pull Day", exercises: [exercise], lastCompleted: nil),
        ])

        let vm = PlanViewModel(userDefaults: testDefaults)

        #expect(vm.workoutPlans.count == 2)
        for plan in vm.workoutPlans {
            #expect(plan.lineageId != nil)
            #expect(plan.fingerprint != nil)
            // Each migrated plan's fingerprint should match what
            // computeFingerprint produces for its exercises — proves the
            // migration ran refreshFingerprint, not just defaulted to "".
            #expect(plan.fingerprint == WorkoutPlan.computeFingerprint(for: plan.exercises))
        }
        // Each plan gets its own freshly-minted lineageId (no accidental
        // shared-pointer issue).
        #expect(vm.workoutPlans[0].lineageId != vm.workoutPlans[1].lineageId)
    }

    @Test func migrationIsIdempotent() {
        let exercise = Exercise(
            name: "Bench Press",
            sets: [Forge.Set(weight: 100, reps: 10, tillFailure: false, completed: false)]
        )
        seedLegacyPlans([
            LegacyPlanBlob(id: UUID(), name: "Push Day", exercises: [exercise], lastCompleted: nil),
        ])

        // First load → migration runs, persists.
        let vm1 = PlanViewModel(userDefaults: testDefaults)
        let firstLineage = vm1.workoutPlans[0].lineageId
        let firstFingerprint = vm1.workoutPlans[0].fingerprint
        let blobAfterFirst = testDefaults.data(forKey: "workoutPlans")

        // Second load → all fields already present, migration should detect
        // no work to do; UserDefaults blob byte-identical.
        let vm2 = PlanViewModel(userDefaults: testDefaults)
        let blobAfterSecond = testDefaults.data(forKey: "workoutPlans")

        #expect(vm2.workoutPlans[0].lineageId == firstLineage)
        #expect(vm2.workoutPlans[0].fingerprint == firstFingerprint)
        #expect(blobAfterFirst == blobAfterSecond)
    }

    @Test func roundTripPreservesLineageAndFingerprint() {
        let exercise = Exercise(
            name: "Bench Press",
            sets: [Forge.Set(weight: 100, reps: 10, tillFailure: false, completed: false)]
        )
        let plan = WorkoutPlan(name: "Shared", exercises: [exercise])
        let originalLineage = plan.lineageId
        let originalFingerprint = plan.fingerprint

        let vm = PlanViewModel(mockPlans: [plan], userDefaults: testDefaults)
        vm.savePlans()
        let reloaded = PlanViewModel(userDefaults: testDefaults)

        #expect(reloaded.workoutPlans[0].lineageId == originalLineage)
        #expect(reloaded.workoutPlans[0].fingerprint == originalFingerprint)
    }
}
