import Foundation

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
