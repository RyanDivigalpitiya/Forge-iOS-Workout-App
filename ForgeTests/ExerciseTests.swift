import Testing
@testable import Forge

/// Covers `Exercise.doesExerciseHaveUniqueSets()` and the `sets` didSet
/// observer that auto-computes `areSetsUnique` and `completed`.
struct ExerciseTests {

    // MARK: - doesExerciseHaveUniqueSets

    @Test func uniformSetsReturnsFalse() {
        let sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 100, reps: 10, tillFailure: false, completed: false)
        ]
        let exercise = Exercise(name: "Bench", sets: sets)
        #expect(exercise.doesExerciseHaveUniqueSets() == false)
    }

    @Test func varyingWeightsReturnsTrue() {
        let sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 110, reps: 10, tillFailure: false, completed: false),
            Set(weight: 120, reps: 10, tillFailure: false, completed: false)
        ]
        let exercise = Exercise(name: "Bench", sets: sets)
        #expect(exercise.doesExerciseHaveUniqueSets() == true)
    }

    @Test func varyingRepsReturnsTrue() {
        let sets = [
            Set(weight: 100, reps: 12, tillFailure: false, completed: false),
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 100, reps: 8, tillFailure: false, completed: false)
        ]
        let exercise = Exercise(name: "Bench", sets: sets)
        #expect(exercise.doesExerciseHaveUniqueSets() == true)
    }

    @Test func varyingTillFailureReturnsTrue() {
        let sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 100, reps: 10, tillFailure: true, completed: false)
        ]
        let exercise = Exercise(name: "Bench", sets: sets)
        #expect(exercise.doesExerciseHaveUniqueSets() == true)
    }

    @Test func emptySetsReturnsFalse() {
        let exercise = Exercise(name: "Empty", sets: [])
        #expect(exercise.doesExerciseHaveUniqueSets() == false)
    }

    @Test func singleSetReturnsFalse() {
        let exercise = Exercise(
            name: "Single",
            sets: [Set(weight: 100, reps: 10, tillFailure: false, completed: false)]
        )
        #expect(exercise.doesExerciseHaveUniqueSets() == false)
    }

    // MARK: - sets didSet observer

    @Test func setsDidSetAutoComputesAreSetsUnique() {
        var exercise = Exercise(
            name: "Bench",
            sets: [
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false)
            ]
        )
        #expect(exercise.areSetsUnique == false)

        // Assigning non-uniform sets should flip areSetsUnique to true.
        exercise.sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 150, reps: 10, tillFailure: false, completed: false)
        ]
        #expect(exercise.areSetsUnique == true)
    }

    @Test func setsDidSetAutoComputesCompleted() {
        var exercise = Exercise(
            name: "Bench",
            sets: [
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false)
            ]
        )
        #expect(exercise.completed == false)

        // Marking all sets completed should flip exercise.completed to true.
        exercise.sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: true),
            Set(weight: 100, reps: 10, tillFailure: false, completed: true)
        ]
        #expect(exercise.completed == true)

        // Marking one set back to not-completed should flip it back.
        exercise.sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: true),
            Set(weight: 100, reps: 10, tillFailure: false, completed: false)
        ]
        #expect(exercise.completed == false)
    }

    // MARK: - breakDurations resize on sets.didSet

    @Test func setsDidSetResizesBreakDurationsOnGrow() {
        var exercise = Exercise(
            name: "Bench",
            sets: [
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false)
            ]
        )
        // Seed a non-nil breakDurations of length 2 (matching 3 sets).
        exercise.breakDurations = [60, 90]
        #expect(exercise.breakDurations?.count == 2)

        // Adding a 4th set should grow breakDurations to length 3.
        exercise.sets.append(Set(weight: 100, reps: 10, tillFailure: false, completed: false))
        #expect(exercise.breakDurations?.count == 3)
        // First two values preserved; third pads from the last known value.
        #expect(exercise.breakDurations?[0] == 60)
        #expect(exercise.breakDurations?[1] == 90)
        #expect(exercise.breakDurations?[2] == 90)
    }

    @Test func setsDidSetResizesBreakDurationsOnShrink() {
        var exercise = Exercise(
            name: "Bench",
            sets: [
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false)
            ]
        )
        exercise.breakDurations = [60, 90, 120]
        #expect(exercise.breakDurations?.count == 3)

        // Drop to 2 sets → breakDurations should shrink to length 1.
        exercise.sets = [
            Set(weight: 100, reps: 10, tillFailure: false, completed: false),
            Set(weight: 100, reps: 10, tillFailure: false, completed: false)
        ]
        #expect(exercise.breakDurations?.count == 1)
        #expect(exercise.breakDurations?[0] == 60)
    }

    @Test func setsDidSetLeavesNilBreakDurationsAlone() {
        // Legacy decode path: breakDurations is nil. Mutating sets should
        // NOT auto-populate it (readers fall back to the global default at
        // use time).
        var exercise = Exercise(
            name: "Bench",
            sets: [
                Set(weight: 100, reps: 10, tillFailure: false, completed: false),
                Set(weight: 100, reps: 10, tillFailure: false, completed: false)
            ]
        )
        exercise.breakDurations = nil

        exercise.sets.append(Set(weight: 100, reps: 10, tillFailure: false, completed: false))
        #expect(exercise.breakDurations == nil)
    }
}
