import Foundation

class PlanViewModel: ObservableObject {
    
    @Published var workoutPlans: [WorkoutPlan]
    
    @Published var activePlan: WorkoutPlan
    @Published var activePlanIndex: Int
    @Published var activePlanMode: String
    
    init() {
        self.workoutPlans = []
        self.activePlan = WorkoutPlan()
        self.activePlanIndex = 0
        self.activePlanMode = "AddMode"
        self.workoutPlans = loadPlans()
    }
    
    init(mockPlans: [WorkoutPlan]) {
        self.workoutPlans = mockPlans
        self.activePlan = mockPlans[0]
        self.activePlanIndex = 0
        self.activePlanMode = "AddMode"
    }
    
    func loadPlans() -> [WorkoutPlan]{
        if let workoutPlansData = UserDefaults.standard.data(forKey: "workoutPlans") {
            if let decodedData = try? JSONDecoder().decode([WorkoutPlan].self, from: workoutPlansData) {
                return decodedData
            } else { return [] }
        } else { return [] }
    }
    
    func savePlans() {
        if let encodedData = try? JSONEncoder().encode(workoutPlans) {
            UserDefaults.standard.set(encodedData, forKey: "workoutPlans")
        }
    }
}
