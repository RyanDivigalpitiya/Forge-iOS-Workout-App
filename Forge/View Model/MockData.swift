import Foundation

// Mock data is used for Preview Structs to populate UI + before loading/saving persistant storage is implemented.
// This file contains only mock data used for these purposes and will be deleted before app is shipped.

// function to create specified number of mock exercise objects and return them in a list.
// This function is used for Preview Structs + before loading/saving persistant storage is implemented.
func createMockExercises(count: Int) -> [Exercise] {
    // array to hold the exercises
    var exercises = [Exercise]()

    // data to generate mock exercises
    let exerciseNames = ["Squats", "Bench Press", "Deadlift", "Overhead Press", "Barbell Row", "Pullups", "Dips", "Curls", "Lunges", "Pushups"]
    let weights: [Float] = [100, 150, 200, 50, 80, 0, 0, 30, 60, 0]
    let reps: [Int] = [12, 10, 8, 12, 12, 10, 10, 15, 12, 20]
    let sets: [Int] = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
    
    // loop to create and add exercises to the array
    for _ in 0..<count {
        // generate random index to pick mock data
        let randomIndex = Int.random(in: 0..<exerciseNames.count)
        
        let exercise = Exercise(id: UUID(), name: exerciseNames[randomIndex], weight: weights[randomIndex], reps: reps[randomIndex], sets: sets[randomIndex], setCompletions: [false, false, false], completed: false)
        exercises.append(exercise)
    }
    
    return exercises
}



// function to create specified number of mock workout plan objects and return them in a list.
// This function is used for Preview Structs + before loading/saving persistant storage is implemented.
func createMockWorkoutPlans(workoutCount: Int, exercisesPerWorkout: Int) -> [WorkoutPlan] {
    // array to hold the workout plans
    var workoutPlans = [WorkoutPlan]()

    // data to generate mock workout plans
    let workoutNames = ["Full Body", "Upper Body", "Lower Body", "Cardio and Core", "Strength and Flexibility"]

    // loop to create and add workout plans to the array
    for _ in 0..<workoutCount {
        // generate random index to pick mock data
        let randomIndex = Int.random(in: 0..<workoutNames.count)

        // generate exercises for this workout
//        let exercises = createMockExercises(count: exercisesPerWorkout)
        let exercises = createMockExercises(count: exercisesPerWorkout)

        // create workout plan with random name and generated exercises
        let workoutPlan = WorkoutPlan(id: UUID(), name: workoutNames[randomIndex], exercises: exercises)
        workoutPlans.append(workoutPlan)
    }

    return workoutPlans
}

// function to create specified number of mock completed workout plan objects and return them in a list.
// This function is used for Preview Structs + before loading/saving persistant storage is implemented.
func createMockCompletedWorkouts(workoutCount: Int, exercisesPerWorkout: Int) -> [CompletedWorkout] {
    // array to hold the completed workouts
    var completedWorkouts = [CompletedWorkout]()

    // create the specified number of workout plans
    let workoutPlans = createMockWorkoutPlans(workoutCount: workoutCount, exercisesPerWorkout: exercisesPerWorkout)

    // loop through each workout plan and create a completed workout for it
    for i in 0..<workoutPlans.count {
        // generate a date from the past "i" days
        let daysAgo = i
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!

        // create a completed workout with the workout plan and calculated date
        let completedWorkout = CompletedWorkout(id: UUID(), date: date, workout: workoutPlans[i])
        completedWorkouts.append(completedWorkout)
    }

    return completedWorkouts
}





// Mock data is used for Preview Structs to populate UI
// This file contains only mock data used for this purpose

// Populate view with placeholder data for now
let exercise1 = Exercise(id: UUID(), name: "Bicep Curls", weight: 50.0, reps: 10, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise2 = Exercise(id: UUID(), name: "Leg Press", weight: 60.0, reps: 8, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise3 = Exercise(id: UUID(), name: "Shoulder Flies", weight: 70.0, reps: 6, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise4 = Exercise(id: UUID(), name: "Calf Raises", weight: 30.0, reps: 8, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise5 = Exercise(id: UUID(), name: "Bench Press", weight: 90.0, reps: 7, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise6 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise7 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise8 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise9 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise10 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise11 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise12 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise13 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise14 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise15 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise16 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise17 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)
let exercise18 = Exercise(id: UUID(), name: "Tricep Extensions", weight: 110.0, reps: 12, sets: 3, setCompletions: [false, false, false], completed: false)

let mockExercises = [
                        exercise1,
                        exercise2,
                        exercise3,
                        exercise4,
                        exercise5,
                        exercise6,
                        exercise7,
                        exercise8,
                        exercise9,
                        exercise10,
                        exercise11,
                        exercise12,
                        exercise13,
                        exercise14,
                        exercise15,
                        exercise16,
                        exercise17,
                        exercise18,
                    ]

// Placeholder data for WorkoutPlan
let workoutPlan1 = WorkoutPlan(id: UUID(), name: "Arm Day", exercises: [exercise1, exercise2])
let workoutPlan2 = WorkoutPlan(id: UUID(), name: "Leg Day", exercises: [exercise2, exercise3])
let workoutPlan3 = WorkoutPlan(id: UUID(), name: "Shoulder Day", exercises: [exercise1, exercise3])
let workoutPlan4 = WorkoutPlan(id: UUID(), name: "Biceps Day", exercises: [exercise1, exercise3])
let workoutPlan5 = WorkoutPlan(id: UUID(), name: "Calves Day", exercises: [exercise1, exercise3])
let workoutPlan6 = WorkoutPlan(id: UUID(), name: "Abs / Obliques", exercises: [exercise1, exercise3])
let workoutPlan7 = WorkoutPlan(id: UUID(), name: "Glutes Day", exercises: [exercise1, exercise3])

let mockWorkouts = [workoutPlan1,workoutPlan2,workoutPlan3,workoutPlan4,workoutPlan5]

let date1 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
let date2 = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
let date3 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
let date4 = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
let date5 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
let date6 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

// Placeholder data for PastWorkout
let pastWorkout1 = CompletedWorkout(id: UUID(), date: Date(), workout: workoutPlan1)
let pastWorkout2 = CompletedWorkout(id: UUID(), date: date1,  workout: workoutPlan2)
let pastWorkout3 = CompletedWorkout(id: UUID(), date: date2,  workout: workoutPlan3)
let pastWorkout4 = CompletedWorkout(id: UUID(), date: date3,  workout: workoutPlan4)
let pastWorkout5 = CompletedWorkout(id: UUID(), date: date4,  workout: workoutPlan5)
let pastWorkout6 = CompletedWorkout(id: UUID(), date: date5,  workout: workoutPlan6)
let pastWorkout7 = CompletedWorkout(id: UUID(), date: date6,  workout: workoutPlan7)

let mockCompletedWorkouts = [pastWorkout1,pastWorkout2,pastWorkout3,pastWorkout4,pastWorkout5,pastWorkout6, pastWorkout7]
