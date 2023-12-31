import Foundation

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

let exercise1 = Exercise(name: "Loooonng Sentence Bicep Curls", sets: mockSets1)
let exercise2 = Exercise(name: "Pull Ups", sets: mockSets2)
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

let completedWorkout1 = CompletedWorkout(date: Date(), workout: workoutPlan1, elapsedTime: 1800, completion: "100%")
let completedWorkout2 = CompletedWorkout(date: Date().addingTimeInterval(-1 * 24 * 60 * 60), workout: workoutPlan2, elapsedTime: 2500, completion: "87%")
let completedWorkout3 = CompletedWorkout(date: Date().addingTimeInterval(-2 * 24 * 60 * 60), workout: workoutPlan3, elapsedTime: 500, completion: "50%")

let mockWorkoutPlans = [workoutPlan1,workoutPlan2,workoutPlan3]
let mockCompletedWorkouts = [completedWorkout1,completedWorkout2,completedWorkout3]
