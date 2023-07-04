import Foundation

class CompletedWorkoutsViewModel: ObservableObject {
    
    @Published var completedWorkouts: [CompletedWorkout]
    @Published var isSelectPlanViewActive: Bool
    
    // default initializer
    init() {
        self.completedWorkouts = []
        self.isSelectPlanViewActive = false
        self.completedWorkouts = loadCompletedWorkouts()
    }
    
    // mock data initializer
    init(mockCompletedWorkouts workouts: [CompletedWorkout]) {
        self.completedWorkouts = workouts
        self.isSelectPlanViewActive = false
    }
}

// FUNCTIONS THAT FORMAT DATA TO BE PRESENTED IN A VIEW
extension CompletedWorkoutsViewModel {
    
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
    
    func format(timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60
        
        if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : ""), \(minutes) minute\(minutes > 1 || minutes == 0 ? "s" : "")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes > 1 || minutes == 0 ? "s" : "")"
        } else {
            return "\(seconds) second\(seconds > 1 || seconds == 0 ? "s" : "")"
        }
    }

}

// SAVING / LOADING PERSISTANT STORAGE
extension CompletedWorkoutsViewModel {
    // loads completedWorkouts from persistant storage (from UserDefaults)
    func loadCompletedWorkouts() -> [CompletedWorkout] {
        if let pastWorkoutData = UserDefaults.standard.data(forKey: "completedWorkouts") {
            if let decodedData = try? JSONDecoder().decode([CompletedWorkout].self, from: pastWorkoutData) {
                return decodedData
            } else { return [] }
        } else { return [] }
    }
    
    // saves completedWorkouts to persistant storage (UserDefaults)
    func saveCompletedWorkouts() {
        if let encodedData = try? JSONEncoder().encode(completedWorkouts) {
            UserDefaults.standard.set(encodedData, forKey: "completedWorkouts")
        }
    }
    
    func deleteCompletedWorkouts(at offsets: IndexSet) {
        completedWorkouts.remove(atOffsets: offsets)
        saveCompletedWorkouts()
    }
}


