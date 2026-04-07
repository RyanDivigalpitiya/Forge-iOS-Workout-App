import Foundation

class ExerciseViewModel: ObservableObject {
    
    @Published var activeExercise: Exercise
    
    @Published var activeExerciseIndex: Int
    @Published var activeExerciseMode: ExerciseEditorMode

    init() {
        self.activeExercise = Exercise()

        self.activeExerciseIndex = 0
        self.activeExerciseMode = .add
    }
}
