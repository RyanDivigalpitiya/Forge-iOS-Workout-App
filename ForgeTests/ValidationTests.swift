import Testing
@testable import Forge

struct ValidationTests {

    @Test func emptyStringReturnsNil() {
        #expect(Validation.trimmedName("") == nil)
    }

    @Test func whitespaceOnlyReturnsNil() {
        #expect(Validation.trimmedName("   ") == nil)
    }

    @Test func normalStringReturnsTrimmed() {
        #expect(Validation.trimmedName("  Bench Press  ") == "Bench Press")
    }

    @Test func stringAtMaxLengthIsUnchanged() {
        let name = String(repeating: "A", count: 50)
        #expect(Validation.trimmedName(name) == name)
    }

    @Test func stringOverMaxLengthIsTruncated() {
        let result = Validation.trimmedName(String(repeating: "A", count: 60))
        #expect(result?.count == 50)
    }

    @Test func singleCharacterIsValid() {
        #expect(Validation.trimmedName("A") == "A")
    }
}

// MARK: - WorkoutPlan fingerprint

/// Pure-function tests for `WorkoutPlan.computeFingerprint(for:)`. Defines
/// structural equality for the upcoming collab same-plan-detection feature.
struct WorkoutPlanFingerprintTests {

    private func setStub() -> Forge.Set {
        Forge.Set(weight: 0, reps: 0, tillFailure: false, completed: false)
    }

    private func ex(_ name: String, setCount: Int) -> Exercise {
        Exercise(name: name, sets: Array(repeating: setStub(), count: setCount))
    }

    @Test func identicalStructureProducesIdenticalFingerprint() {
        let a = [ex("Bench Press", setCount: 3), ex("Incline Press", setCount: 3)]
        let b = [ex("Bench Press", setCount: 3), ex("Incline Press", setCount: 3)]
        #expect(WorkoutPlan.computeFingerprint(for: a) == WorkoutPlan.computeFingerprint(for: b))
    }

    @Test func caseDifferencesAreIgnored() {
        let upper = [ex("Bench Press", setCount: 3)]
        let lower = [ex("bench press", setCount: 3)]
        let mixed = [ex("BeNcH pReSs", setCount: 3)]
        let fp = WorkoutPlan.computeFingerprint(for: upper)
        #expect(WorkoutPlan.computeFingerprint(for: lower) == fp)
        #expect(WorkoutPlan.computeFingerprint(for: mixed) == fp)
    }

    @Test func surroundingWhitespaceIsIgnored() {
        let trimmed = [ex("Bench Press", setCount: 3)]
        let padded = [ex("  Bench Press  ", setCount: 3)]
        let newlined = [ex("\nBench Press\n", setCount: 3)]
        let fp = WorkoutPlan.computeFingerprint(for: trimmed)
        #expect(WorkoutPlan.computeFingerprint(for: padded) == fp)
        #expect(WorkoutPlan.computeFingerprint(for: newlined) == fp)
    }

    @Test func differentSetCountProducesDifferentFingerprint() {
        let a = [ex("Bench Press", setCount: 3)]
        let b = [ex("Bench Press", setCount: 4)]
        #expect(WorkoutPlan.computeFingerprint(for: a) != WorkoutPlan.computeFingerprint(for: b))
    }

    @Test func differentExerciseOrderProducesDifferentFingerprint() {
        let a = [ex("Bench Press", setCount: 3), ex("Incline Press", setCount: 3)]
        let b = [ex("Incline Press", setCount: 3), ex("Bench Press", setCount: 3)]
        #expect(WorkoutPlan.computeFingerprint(for: a) != WorkoutPlan.computeFingerprint(for: b))
    }

    @Test func differentExerciseNameProducesDifferentFingerprint() {
        let a = [ex("Bench Press", setCount: 3)]
        let b = [ex("Bent-over Row", setCount: 3)]
        #expect(WorkoutPlan.computeFingerprint(for: a) != WorkoutPlan.computeFingerprint(for: b))
    }

    @Test func setWeightAndRepsDoNotAffectFingerprint() {
        let lightSets = Array(repeating: Forge.Set(weight: 10, reps: 5, tillFailure: false, completed: false), count: 3)
        let heavySets = Array(repeating: Forge.Set(weight: 200, reps: 12, tillFailure: true, completed: true), count: 3)
        let lightExercise = Exercise(name: "Bench Press", sets: lightSets)
        let heavyExercise = Exercise(name: "Bench Press", sets: heavySets)
        #expect(
            WorkoutPlan.computeFingerprint(for: [lightExercise]) ==
            WorkoutPlan.computeFingerprint(for: [heavyExercise])
        )
    }

    @Test func emptyExercisesListProducesDeterministicHash() {
        let fp = WorkoutPlan.computeFingerprint(for: [])
        // SHA-256 hex output is exactly 64 chars regardless of input.
        #expect(fp.count == 64)
        #expect(WorkoutPlan.computeFingerprint(for: []) == fp)
    }

    @Test func didSetRefreshesFingerprintWhenExerciseNameChanges() {
        var plan = WorkoutPlan(name: "Push Day", exercises: [ex("Bench Press", setCount: 3)])
        let initial = plan.fingerprint
        plan.exercises[0].name = "Incline Press"
        #expect(plan.fingerprint != initial)
        #expect(plan.fingerprint != nil)
    }

    @Test func didSetRefreshesFingerprintWhenSetCountChanges() {
        var plan = WorkoutPlan(name: "Push Day", exercises: [ex("Bench Press", setCount: 3)])
        let initial = plan.fingerprint
        plan.exercises[0].sets.append(setStub())
        #expect(plan.fingerprint != initial)
    }

    @Test func setCompletedToggleDoesNotAffectFingerprint() {
        var plan = WorkoutPlan(name: "Push Day", exercises: [ex("Bench Press", setCount: 3)])
        let initial = plan.fingerprint
        plan.exercises[0].sets[0].completed = true
        #expect(plan.fingerprint == initial)
    }

    @Test func planNameDoesNotAffectFingerprint() {
        let push = WorkoutPlan(name: "Push Day", exercises: [ex("Bench Press", setCount: 3)])
        let chest = WorkoutPlan(name: "Chest Day", exercises: [ex("Bench Press", setCount: 3)])
        #expect(push.fingerprint == chest.fingerprint)
    }
}
