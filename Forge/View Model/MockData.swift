import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Mock data is used for Preview Structs to populate UI + before loading/saving persistant storage is implemented.
// This file contains only mock data used for these purposes and will be deleted when app is shipped.

let set1 = Set(weight: 25, reps: 12, tillFailure: false, completed: false)
let set2 = Set(weight: 30, reps: 10, tillFailure: false, completed: false)
let set3 = Set(weight: 35, reps: 8, tillFailure: false, completed: false)
let set3_f = Set(weight: 35, reps: 8, tillFailure: true, completed: false)

let mockSets1 = [set1,set2,set3,set3_f]

let set4 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
let set5 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
let set6 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)

let mockSets2 = [set4,set5,set6]

let exercise1 = Exercise(name: "Bicep Curls", sets: mockSets1)
let exercise2 = Exercise(name: "Loooonng Sentence Pull Ups", sets: mockSets2)
let exercise3 = Exercise(name: "Back Rows", sets: mockSets2)

let mockExercises1 = [exercise1,exercise2,exercise3]

let workoutPlan1 = WorkoutPlan(name: "Biceps + Back", exercises: mockExercises1, lastCompleted: Date().addingTimeInterval(-1 * 24 * 60 * 60))

let exercise4 = Exercise(name: "Bench Press", sets: mockSets2)
let exercise5 = Exercise(name: "Tricep Extensions", sets: mockSets2)
let exercise6 = Exercise(name: "Chest Flies", sets: mockSets2)

let mockExercises2 = [exercise4,exercise5,exercise6]

let workoutPlan2 = WorkoutPlan(name: "Chest + Triceps", exercises: mockExercises2, lastCompleted: Date().addingTimeInterval(-2 * 24 * 60 * 60))

let exercise7 = Exercise(name: "Elbow Chicken Flies", sets: mockSets1)
let exercise8 = Exercise(name: "Shoulder Flies", sets: mockSets1)
let exercise9 = Exercise(name: "Shoulder Press", sets: mockSets1)

let mockExercises3 = [exercise7,exercise8,exercise9]

let workoutPlan3 = WorkoutPlan(name: "Shoulders", exercises: mockExercises3, lastCompleted: Date().addingTimeInterval(-3 * 24 * 60 * 60))

let completedWorkout1 = CompletedWorkout(date: Date(), workout: workoutPlan1, elapsedTime: 1800, completion: "100%", caloriesBurned: 342)
let completedWorkout2 = CompletedWorkout(date: Date().addingTimeInterval(-1 * 24 * 60 * 60), workout: workoutPlan2, elapsedTime: 2500, completion: "87%", caloriesBurned: 278)
let completedWorkout3 = CompletedWorkout(date: Date().addingTimeInterval(-2 * 24 * 60 * 60), workout: workoutPlan3, elapsedTime: 500, completion: "50%")

let mockWorkoutPlans = [workoutPlan1,workoutPlan2,workoutPlan3]
let mockCompletedWorkouts = [completedWorkout1,completedWorkout2,completedWorkout3]

// MARK: - Body weight mock data

private let dayInSeconds: TimeInterval = 86_400
private let bwNow = Date()

let mockBodyWeightEntries: [BodyWeightEntry] = [
    BodyWeightEntry(date: bwNow,                                          weightLbs: 178.5),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-2 * dayInSeconds),    weightLbs: 178.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-7 * dayInSeconds),    weightLbs: 177.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-14 * dayInSeconds),   weightLbs: 175.5),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-25 * dayInSeconds),   weightLbs: 173.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-45 * dayInSeconds),   weightLbs: 170.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-75 * dayInSeconds),   weightLbs: 168.5),
]

// MARK: - Progress photos mock data

#if canImport(UIKit) && DEBUG

private func makeMockProgressImage(_ color: UIColor, label: String) -> UIImage {
    let size = CGSize(width: 400, height: 500)
    return UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let textSize = label.size(withAttributes: attrs)
        let origin = CGPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        label.draw(at: origin, withAttributes: attrs)
    }
}

/// Builds a `ProgressPhotosViewModel` seeded with three entries (1, 2, and 3
/// poses respectively) backed by synthesized UIImages on a per-call temp
/// directory. The directory is unique per call so previews don't clobber
/// each other.
@MainActor
func makeMockProgressPhotosVM() -> ProgressPhotosViewModel {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ForgePreviewPhotos.\(UUID().uuidString)", isDirectory: true)
    let suite = UserDefaults(suiteName: "ForgePreview.\(UUID().uuidString)")!
    let vm = ProgressPhotosViewModel(userDefaults: suite, photosDirectory: dir)
    let day: TimeInterval = 86_400
    let now = Date()
    vm.addEntry(
        date: now,
        front: makeMockProgressImage(.systemRed, label: "F"),
        side: makeMockProgressImage(.systemBlue, label: "S"),
        back: makeMockProgressImage(.systemGreen, label: "B")
    )
    vm.addEntry(
        date: now.addingTimeInterval(-14 * day),
        front: makeMockProgressImage(.systemOrange, label: "F"),
        side: nil,
        back: makeMockProgressImage(.systemPurple, label: "B")
    )
    vm.addEntry(
        date: now.addingTimeInterval(-45 * day),
        front: makeMockProgressImage(.systemTeal, label: "F"),
        side: nil,
        back: nil
    )
    return vm
}

#endif
