import Foundation

class ExerciseViewModel: ObservableObject {
    
    @Published var activeExercise: Exercise
    
    @Published var activeExerciseIndex: Int
    @Published var activeExerciseMode: String
    
    @Published var previousWeightValue: Float
    @Published var previousRepsValue: Int
    @Published var previousSetsValue: Int
    
    init() {
        self.activeExercise = Exercise()
        
        self.activeExerciseIndex = 0
        self.activeExerciseMode = "AddMode"
        
        self.previousWeightValue = 5
        self.previousRepsValue = 12
        self.previousSetsValue = 3
        
        self.previousWeightValue = self.activeExercise.weight
        self.previousRepsValue = self.activeExercise.reps
        self.previousSetsValue = self.activeExercise.sets
    }
}
