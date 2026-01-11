import Foundation

struct Set: Identifiable, Encodable, Decodable {
    var id: UUID
    var weight: Float
    var reps: Int
    var tillFailure: Bool
    var completed: Bool
    
    // empty initializer
    init() {
        self.id = UUID()
        self.weight = 5.0
        self.reps = 12
        self.tillFailure = false
        self.completed = false
    }
    
    init(weight: Float, reps: Int, tillFailure: Bool, completed: Bool) {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.tillFailure = tillFailure
        self.completed = completed
    }
}

struct Exercise: Identifiable, Encodable, Decodable {
    var id: UUID
    var name: String
    var sets: [Set] {
        didSet {
            self.areSetsUnique = doesExerciseHaveUniqueSets()
            // Check if all sets are completed
            if sets.allSatisfy({ $0.completed }) {
                self.completed = true
            } else {
                self.completed = false
            }
        }
    }
    var areSetsUnique: Bool
    var completed: Bool
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.sets = [Set(), Set(), Set()]
        self.completed = false
        self.areSetsUnique = false
        self.areSetsUnique = doesExerciseHaveUniqueSets()
    }
    
    // create new Exercise object with specified params
    init(name: String, sets: [Set]) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.completed = false
        self.areSetsUnique = false
        self.areSetsUnique = doesExerciseHaveUniqueSets()
    }
    
    func doesExerciseHaveUniqueSets() -> Bool {
        /**
        This function checks if the given array of `Set` objects has unique weights, reps or 'tillFailure' values.

        The function checks each set in the array. If it finds a set with a different weight, reps or 'tillFailure' value than the first set in the array, the function immediately returns `true`, indicating that the sets are unique.

        If all sets in the array have the same weight, reps and 'tillFailure' value as the first set, the function returns `false`, indicating that the sets are not unique.

        This function is used to determine if an exercise's sets have varying weights, reps or 'tillFailure' values, which could indicate a more complex or variable intensity exercise routine.

        Parameters:
        - sets: An array of `Set` objects that needs to be checked for uniqueness in terms of weight, reps and 'tillFailure' values.

        Returns:
        - A `Bool` indicating whether the array of sets contains unique weights, reps or 'tillFailure' values (`true`), or all sets are identical in these terms (`false`).
        */
        // compare weight values
        
        if !sets.isEmpty {
            let weight = sets[0].weight
            for set in sets {
                if !(set.weight == weight) {
                    return true
                }
            }
            // compare rep values
            let rep = sets[0].reps
            for set in sets {
                if !(set.reps == rep) {
                    return true
                }
            }
            // compare tillFailure values
            let tillFailure = sets[0].tillFailure
            for set in sets {
                if !(set.tillFailure == tillFailure) {
                    return true
                }
            }
        }
        // if we make to here, then all weights, reps and tillFailure values are the same for all sets ∴ return true:
        return false
    }
}

struct WorkoutPlan: Identifiable, Encodable, Decodable {
    var id: UUID
    var name: String 
    var exercises: [Exercise]
    var lastCompleted: Date?
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.exercises = []
    }
    
    // create new WorkoutPlan object with specified params
    init(name: String, exercises: [Exercise], lastCompleted: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
        self.lastCompleted = lastCompleted
    }
    
    //function to create copy of WorkoutPlan object
    init(copy: WorkoutPlan) {
        self.id = copy.id
        self.name = copy.name
        self.exercises = copy.exercises
        self.lastCompleted = copy.lastCompleted
    }

}

struct CompletedWorkout: Identifiable, Encodable, Decodable {
    var id: UUID
    var dateCompleted: Date
    var elapsedTime: TimeInterval
    var workout: WorkoutPlan
    var completion: String
    
    init() {
        self.id = UUID()
        self.dateCompleted = Date()
        self.elapsedTime = TimeInterval()
        self.workout = WorkoutPlan()
        self.completion = "0 Minutes"
    }
    
    // create new  CompletedWorkouts object with specified params
    init(date: Date, workout: WorkoutPlan, elapsedTime: TimeInterval, completion: String) {
        self.id = UUID()
        self.dateCompleted = date
        self.elapsedTime = elapsedTime
        self.workout = workout
        self.completion = completion
    }
}

//func createMockExercises(count: Int) -> [Exercise] {
//    // array to hold the exercises
//    var exercises = [Exercise]()
//
//    // data to generate mock exercises
//    let exerciseNames = ["Squats", "Bench Press", "Deadlift", "Overhead Press", "Barbell Row", "Pullups", "Dips", "Curls", "Lunges", "Pushups"]
//    let weights: [Float] = [100, 150, 200, 50, 80, 0, 0, 30, 60, 0]
//    let reps: [Int] = [12, 10, 8, 12, 12, 10, 10, 15, 12, 20]
//    let sets: [Int] = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
//    
//    // loop to create and add exercises to the array
//    for _ in 0..<count {
//        // generate random index to pick mock data
//        let randomIndex = Int.random(in: 0..<exerciseNames.count)
//        
//        let exercise = Exercise(name: exerciseNames[randomIndex], weight: weights[randomIndex], reps: reps[randomIndex], sets: sets[randomIndex], setCompletions: [false, false, false], completed: false)
//        exercises.append(exercise)
//    }
//    
//    return exercises
//}

//func createMockWorkoutPlans(workoutCount: Int, exercisesPerWorkout: Int) -> [WorkoutPlan] {
//    // array to hold the workout plans
//    var workoutPlans = [WorkoutPlan]()
//
//    // data to generate mock workout plans
//    let workoutNames = ["Full Body", "Upper Body", "Lower Body", "Cardio and Core", "Strength and Flexibility"]
//
//    // loop to create and add workout plans to the array
//    for i in 0..<workoutCount {
//        // generate random index to pick mock data
//        let randomIndex = Int.random(in: 0..<workoutNames.count)
//
//        // generate exercises for this workout
////        let exercises = createMockExercises(count: exercisesPerWorkout)
//        let exercises = createMockExercises(count: exercisesPerWorkout)
//
//        // create workout plan with random name and generated exercises
//        let workoutPlan = WorkoutPlan(name: workoutNames[randomIndex], exercises: exercises)
//        workoutPlans.append(workoutPlan)
//    }
//
//    return workoutPlans
//}

//func createMockCompletedWorkouts(workoutCount: Int, exercisesPerWorkout: Int) -> [CompletedWorkout] {
//    // array to hold the completed workouts
//    var completedWorkouts = [CompletedWorkout]()
//
//    // create the specified number of workout plans
//    let workoutPlans = createMockWorkoutPlans(workoutCount: workoutCount, exercisesPerWorkout: exercisesPerWorkout)
//
//    // loop through each workout plan and create a completed workout for it
//    for workoutPlan in workoutPlans {
//        // generate a random date from the past 30 days
//        let randomDaysAgo = Int.random(in: 0..<30)
//        let randomDate = Calendar.current.date(byAdding: .day, value: -randomDaysAgo, to: Date())!
//
//        // create a completed workout with the workout plan and random date
//        let completedWorkout = CompletedWorkout(date: randomDate, workout: workoutPlan)
//        completedWorkouts.append(completedWorkout)
//    }
//
//    return completedWorkouts
//}

func parseWorkoutPlanFromLLM(from input: String) -> WorkoutPlan? {
    // Split the input into lines
    let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }
    
    guard let planLine = lines.first, planLine.starts(with: "Plan:") else {
        print("Invalid format: Missing or invalid plan name.")
        return nil
    }
    
    // Extract the workout plan name
    let planName = planLine.replacingOccurrences(of: "Plan: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Process exercises
    var exercises: [Exercise] = []
    
    // Regex to match exercise format: "Exercise Name: X sets x Y lbs x Z reps"
    let regex = try! NSRegularExpression(pattern: #"(.+): (\d+) sets x (\d+) lbs x (\d+) reps"#, options: [])
    
    for line in lines.dropFirst() {
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count))
        
        guard let match = matches.first else {
            print("Invalid format for line: \(line)")
            continue
        }
        
        // Extract exercise name
        let exerciseNameRange = Range(match.range(at: 1), in: line)!
        let exerciseName = String(line[exerciseNameRange])
        
        // Extract sets, weight, and reps
        let setsCountRange = Range(match.range(at: 2), in: line)!
        let weightRange = Range(match.range(at: 3), in: line)!
        let repsRange = Range(match.range(at: 4), in: line)!
        
        let setsCount = Int(line[setsCountRange])!
        let weight = Float(line[weightRange])!
        let reps = Int(line[repsRange])!
        
        // Create `Set` objects
        let sets = (0..<setsCount).map { _ in
            Set(weight: weight, reps: reps, tillFailure: false, completed: false)
        }
        
        // Create `Exercise` object
        let exercise = Exercise(name: exerciseName, sets: sets)
        exercises.append(exercise)
    }
    
    // Create and return the `WorkoutPlan` object
    return WorkoutPlan(name: planName, exercises: exercises)
}


// TESTING LLM PARSER
let rawInput = """
Plan: Full Body Workout

Push Ups: 3 sets x 0 lbs x 15 reps
Squats: 3 sets x 20 lbs x 10 reps
Deadlifts: 4 sets x 50 lbs x 8 reps
"""

if let workoutPlan = parseWorkoutPlanFromLLM(from: rawInput) {
    print("Workout Plan: \(workoutPlan.name)")
    for exercise in workoutPlan.exercises {
        print("Exercise: \(exercise.name)")
        print("Unique Sets: \(exercise.areSetsUnique)")
        for set in exercise.sets {
            print("  Weight: \(set.weight), Reps: \(set.reps), Completed: \(set.completed)")
        }
    }
} else {
    print("Failed to parse workout plan.")
}


// Testing exercises model
//let testingExercises = false
//if testingExercises {
//    let exercises = createMockExercises(count: 3)
//
//    for exercise in exercises {
//        print(exercise.name)
//        print(exercise.sets)
//        print(exercise.reps)
//        print(exercise.completed)
//        for completions in exercise.setCompletions {
//            print("Set completed:" + String(completions))
//        }
//        print()
//        print("-----")
//        print()
//}
//}
//
//// Testing plan model
//let testingPlans = false
//if testingPlans {
//    let plans = createMockWorkoutPlans(workoutCount: 2, exercisesPerWorkout: 2)
//
//    for plan in plans {
//        print(plan.name)
//        for exercise in plan.exercises {
//            print(exercise.name)
//            print(exercise.sets)
//            print(exercise.reps)
//            print(exercise.completed)
//            for completions in exercise.setCompletions {
//                print("Set completed:" + String(completions))
//            }
//            print()
//            print("-----")
//            print()
//        }
//    }
//}
//
//
//// testing CompletedWorkouts
//let testingCompletedWorkouts = false
//if testingCompletedWorkouts {
//    let completedWorkouts = createMockCompletedWorkouts(workoutCount: 2, exercisesPerWorkout: 2)
//
//    for completedWorkout in completedWorkouts {
//        print(completedWorkout.workout.name)
//        print(completedWorkout.date)
//        print()
//        print(completedWorkout.workout.name)
//        for exercise in completedWorkout.workout.exercises {
//            print(exercise.name)
//            print(exercise.sets)
//            print(exercise.reps)
//            print(exercise.completed)
//            for completions in exercise.setCompletions {
//                print("Set completed:" + String(completions))
//            }
//            print()
//            print("-----")
//            print()
//        }
//    }
//}
//
