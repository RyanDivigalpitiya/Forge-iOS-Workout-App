import Foundation

class Exercise: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var name: String

    var weight: Float
    var reps: Int
    var sets: Int

    var setCompletions: [Bool]
    var completed: Bool

    // default initializer
    init() {
        self.id = UUID()
        self.name = ""

        self.weight = 0
        self.reps = 12
        self.sets = 3

        self.setCompletions = [false,false,false]
        self.completed = false
    }

    // create new Exercise object with specified params
    init(id: UUID, name: String, weight: Float, reps: Int, sets: Int, setCompletions: [Bool], completed: Bool) {
        self.id = id
        self.name = name

        self.weight = weight
        self.reps = reps
        self.sets = sets

        self.setCompletions = setCompletions
        self.completed = completed
    }

    // equality operator for Exercise objects
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.name == rhs.name &&
                lhs.weight == rhs.weight &&
                lhs.reps == rhs.reps &&
                lhs.sets == rhs.sets &&
                lhs.setCompletions == rhs.setCompletions &&
                lhs.completed == rhs.completed
    }
}

class WorkoutPlan: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var name: String
    var exercises: [Exercise]

    // default initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.exercises = []
    }

    // create new WorkoutPlan object with specified params
    init(id: UUID, name: String, exercises: [Exercise]) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
    }

    // equality operator for WorkoutPlan objects
    static func == (lhs: WorkoutPlan, rhs: WorkoutPlan) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.name == rhs.name &&
                lhs.exercises == lhs.exercises
    }
}

class CompletedWorkouts: Identifiable, Equatable, Encodable, Decodable {
    var id: UUID
    var date: Date
    var workout: WorkoutPlan

    // create new  CompletedWorkouts object with specified params
    init(id: UUID, date: Date, workout: WorkoutPlan) {
        self.id = id
        self.date = date
        self.workout = workout
    }

    // equality operator for CompletedWorkouts objects
    static func == (lhs: CompletedWorkouts, rhs: CompletedWorkouts) -> Bool {
        return  lhs.id == rhs.id &&
                lhs.date == rhs.date &&
                lhs.workout == rhs.workout
    }
}

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

func createMockWorkoutPlans(workoutCount: Int, exercisesPerWorkout: Int) -> [WorkoutPlan] {
    // array to hold the workout plans
    var workoutPlans = [WorkoutPlan]()

    // data to generate mock workout plans
    let workoutNames = ["Full Body", "Upper Body", "Lower Body", "Cardio and Core", "Strength and Flexibility"]

    // loop to create and add workout plans to the array
    for i in 0..<workoutCount {
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

// Testing exercises model
let testingExercises = false
if testingExercises {
    let exercises = createMockExercises(count: 3)

    for exercise in exercises {
        print(exercise.name)
        print(exercise.sets)
        print(exercise.reps)
        print(exercise.completed)
        for completions in exercise.setCompletions {
            print("Set completed:" + String(completions))
        }
        print()
        print("-----")
        print()
}
}

// Testing plan model
let testingPlans = false
if testingPlans {
    let plans = createMockWorkoutPlans(workoutCount: 2, exercisesPerWorkout: 2)

    for plan in plans {
        print(plan.name)
        for exercise in plan.exercises {
            print(exercise.name)
            print(exercise.sets)
            print(exercise.reps)
            print(exercise.completed)
            for completions in exercise.setCompletions {
                print("Set completed:" + String(completions))
            }
            print()
            print("-----")
            print()
        }
    }
}


// testing CompletedWorkouts
testingCompletedWorkouts = false

if testingCompletedWorkouts {
    let completedWorkouts = createMockCompletedWorkouts(workoutCount: 2, exercisesPerWorkout: 2)

    for completedWorkout in completedWorkouts {
        print(completedWorkout.workout.name)
        print(completedWorkout.date)
        print()
        print(completedWorkout.workout.name)
        for exercise in completedWorkout.workout.exercises {
            print(exercise.name)
            print(exercise.sets)
            print(exercise.reps)
            print(exercise.completed)
            for completions in exercise.setCompletions {
                print("Set completed:" + String(completions))
            }
            print()
            print("-----")
            print()
        }
    }
}
