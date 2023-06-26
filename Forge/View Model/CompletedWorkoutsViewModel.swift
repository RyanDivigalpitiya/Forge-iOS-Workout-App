import Foundation

class CompletedWorkoutsViewModel: ObservableObject {
    
    @Published var completedWorkouts: [CompletedWorkout]
    
    // default initializer
    init() {
        self.completedWorkouts = []
        self.completedWorkouts = loadCompletedWorkouts()
    }
    
    // mock data initializer
    init(mockCompletedWorkouts workouts: [CompletedWorkout]) {
        self.completedWorkouts = workouts
    }
    
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
}
