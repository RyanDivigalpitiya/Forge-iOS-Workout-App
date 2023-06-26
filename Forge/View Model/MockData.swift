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
func createMockCompletedWorkouts(workoutCount: Int, exercisesPerWorkout: Int) -> [CompletedWorkouts] {
    // array to hold the completed workouts
    var completedWorkouts = [CompletedWorkouts]()

    // create the specified number of workout plans
    let workoutPlans = createMockWorkoutPlans(workoutCount: workoutCount, exercisesPerWorkout: exercisesPerWorkout)

    // loop through each workout plan and create a completed workout for it
    for workoutPlan in workoutPlans {
        // generate a random date from the past 30 days
        let randomDaysAgo = Int.random(in: 0..<30)
        let randomDate = Calendar.current.date(byAdding: .day, value: -randomDaysAgo, to: Date())!

        // create a completed workout with the workout plan and random date
        let completedWorkout = CompletedWorkouts(id: UUID(), date: randomDate, workout: workoutPlan)
        completedWorkouts.append(completedWorkout)
    }

    return completedWorkouts
}
