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
}
