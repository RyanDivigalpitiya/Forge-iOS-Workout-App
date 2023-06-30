import Foundation

// This file is for UNIT TESTS + manually testing code found in view models.

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

import Foundation

struct Exercise: Identifiable, Encodable, Decodable {
    var id: UUID
    var name: String
    var sets: [Set]
    var completed: Bool
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.sets = []
        self.completed = false
    }
    
    // create new Exercise object with specified params
    init(name: String, sets: [Set], completed: Bool) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.completed = completed
    }
}
import Foundation

struct WorkoutPlan: Identifiable, Encodable, Decodable {
    var id: UUID
    var name: String
    var exercises: [Exercise]
    
    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.exercises = []
    }
    
    // create new WorkoutPlan object with specified params
    init(name: String, exercises: [Exercise]) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
    }
}



// testing containsUniqueSets()
func containsUniqueSets(in sets: [Set]) -> Bool {
    
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

// Mock data used for testing

let set1 = Set(weight: 25, reps: 12, tillFailure: false, completed: false)
let set2 = Set(weight: 25, reps: 12, tillFailure: false, completed: false)
let set3 = Set(weight: 25, reps: 12, tillFailure: false, completed: false)

let mockSets1 = [set1,set2,set3]

let set4 = Set(weight: 100, reps: 12, tillFailure: true, completed: false)
let set5 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
let set6 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)

let mockSets2 = [set4,set5,set6]

let testSet0 = mockSets1        // pass: containsUniqueSets() -> false
let testSet1 = [set1,set4,set6] // pass: containsUniqueSets() -> true
let testSet2 = [set1,set1,set1] // pass: containsUniqueSets() -> false
let testSet3 = [set4,set5,set6] // pass: containsUniqueSets() -> true
let testSet4 = [set4,set3,set6] // pass: containsUniqueSets() -> true

// mockSets1 -> false is a pass
if containsUniqueSets(in: testSet0) == false {
    print("Test passed")
} else { print("Test failed") }

// testSet1 -> false is a pass
if containsUniqueSets(in: testSet1) == true {
    print("Test passed")
} else { print("Test failed") }

// testSet2 -> false is a pass
if containsUniqueSets(in: testSet2) == false {
    print("Test passed")
} else { print("Test failed") }

// testSet3 -> false is a pass
if containsUniqueSets(in: testSet3) == true {
    print("Test passed")
} else { print("Test failed") }

// testSet4 -> false is a pass
if containsUniqueSets(in: testSet4) == true {
    print("Test passed")
} else { print("Test failed") }


let exercise1 = Exercise(name: "Bicep Curls", sets: mockSets1, completed: false)
let exercise2 = Exercise(name: "Pull Ups", sets: mockSets1, completed: false)
let exercise3 = Exercise(name: "Back Rows", sets: mockSets1, completed: false)

let mockExercises1 = [exercise1,exercise2,exercise3]

let workoutPlan1 = WorkoutPlan(name: "Biceps + Back", exercises: mockExercises1)

let exercise4 = Exercise(name: "Bench Press", sets: mockSets2, completed: false)
let exercise5 = Exercise(name: "Tricep Extensions", sets: mockSets2, completed: false)
let exercise6 = Exercise(name: "Chest Flies", sets: mockSets2, completed: false)

let mockExercises2 = [exercise4,exercise5,exercise6]

let workoutPlan2 = WorkoutPlan(name: "Chest + Triceps", exercises: mockExercises2)

let exercise7 = Exercise(name: "Elbow Chicken Flies", sets: mockSets1, completed: false)
let exercise8 = Exercise(name: "Shoulder Flies", sets: mockSets1, completed: false)
let exercise9 = Exercise(name: "Shoulder Press", sets: mockSets1, completed: false)

let mockExercises3 = [exercise7,exercise8,exercise9]

let workoutPlan3 = WorkoutPlan(name: "Shoulders", exercises: mockExercises3)





func calculateWorkoutDuration(for plan: WorkoutPlan) -> Int {
    
    let breakTime = 60 // 60 second break timer
    let repTime = 2 // 2 seconds per rep
    
    //loop through sets and exercises while adding duration length to "workoutTime":
    var workoutTime = 0
    for exercise in plan.exercises {
        var exerciseTime = 0
        for set in exercise.sets {
            let repCount = set.reps
            exerciseTime = exerciseTime + repCount*repTime + breakTime
        }
        workoutTime = workoutTime + (exerciseTime-60)
    }
    
    if workoutTime > 60 {
        workoutTime = Int(workoutTime / 60)
    } else {
        return 0 // if workoutTime is less than 60 seconds, simply round down to 0; no need for second-accuracy estimation of workout duration
    }
    return workoutTime
}

// 3*((3*(12*2 + 60))-60) = 576 for workoutPlan 1
// test calculateWorkoutDuration() for workoutPlan 1, should be 576 / 60
if calculateWorkoutDuration(for: workoutPlan1) == Int(576/60) {
    print("Test passed.")
    } else { print("Test failed.") }


// edge case: 1 set, 1 rep workout plan:
let shortSet = Set(weight: 25, reps: 1, tillFailure: false, completed: false)
let shortExercise = Exercise(name: "short exer", sets: [shortSet], completed: false)
let shortWorkout = WorkoutPlan(name: "short plan", exercises: [shortExercise])

print( calculateWorkoutDuration(for: shortWorkout) )



func numberOfDaysString(from date: Date) -> String {
    /*
        returns "Today" if Date() is sometime between now and 12:00am today,
        or returns "Yesterday" if Date() is sometime between yesterday 11:59pm and yesterday 12:00am,
        or "x Days ago" if Date() is from before yesterday an x number of days ago
    */
    
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Today"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else {
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        if let day = components.day {
            return "\(day) days ago"
        } else {
            return "Date calculation error" //change how error handling is done here
        }
    }
}

let calendar = Calendar.current
let now = Date()

// Today
let today = now

// Yesterday
guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
    fatalError("Couldn't calculate yesterday's date")
}

// 2 days ago
guard let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) else {
    fatalError("Couldn't calculate the date of 2 days ago")
}

// 5 days ago
guard let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now) else {
    fatalError("Couldn't calculate the date of 5 days ago")
}

// 10 days ago
guard let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now) else {
    fatalError("Couldn't calculate the date of 10 days ago")
}

let datesToTest = [today, yesterday, twoDaysAgo, fiveDaysAgo, tenDaysAgo]

for date in datesToTest {
    print(numberOfDaysString(from: date))
}

