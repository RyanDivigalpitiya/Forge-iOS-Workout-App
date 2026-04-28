import Foundation

/// Selector axis for the per-exercise progress chart in `HistoryView`'s
/// Full History tab. Top-level so views can reference it without
/// qualification.
enum ProgressMetric {
    case weight
    case reps
}

class CompletedWorkoutsViewModel: ObservableObject {

    @Published var completedWorkouts: [CompletedWorkout]
    @Published var isSelectPlanViewActive: Bool
    @Published var activePlan: CompletedWorkout

    private let userDefaults: UserDefaults

    // default initializer
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.completedWorkouts = []
        self.isSelectPlanViewActive = false
        self.activePlan = CompletedWorkout()
        self.completedWorkouts = loadCompletedWorkouts()
    }

    // mock data initializer
    init(mockCompletedWorkouts workouts: [CompletedWorkout], userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.completedWorkouts = workouts
        self.isSelectPlanViewActive = false
        self.activePlan = CompletedWorkout()
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy" // specify the format
        return formatter.string(from: date)
    }
}

// SAVING / LOADING PERSISTANT STORAGE
extension CompletedWorkoutsViewModel {
    // loads completedWorkouts from persistant storage (from UserDefaults)
    func loadCompletedWorkouts() -> [CompletedWorkout] {
        if let pastWorkoutData = userDefaults.data(forKey: "completedWorkouts") {
            if let decodedData = try? JSONDecoder().decode([CompletedWorkout].self, from: pastWorkoutData) {
                return decodedData
            } else { return [] }
        } else { return [] }
    }

    // saves completedWorkouts to persistant storage (UserDefaults)
    func saveCompletedWorkouts() {
        if let encodedData = try? JSONEncoder().encode(completedWorkouts) {
            userDefaults.set(encodedData, forKey: "completedWorkouts")
        }
    }
    
    func deleteCompletedWorkouts(at offsets: IndexSet) {
        // completed workouts in the list are displayed in reverse order, so must compute actualIndicies:
        let actualIndices = offsets.map { completedWorkouts.count - 1 - $0 }
        // remove items at actual indices
        completedWorkouts.remove(atOffsets: IndexSet(actualIndices))
        saveCompletedWorkouts()
    }
}

// MARK: - Progress History (Phase B)

extension CompletedWorkoutsViewModel {

    /// One data point per CompletedWorkout that contains this exercise's
    /// UUID, sorted by date ascending. Each point reports the max value
    /// among COMPLETED sets — incomplete sets are excluded so progress
    /// reflects what was actually performed (matches "Fail Loud, Never
    /// Fake" — don't count phantom data). Workouts where the exercise
    /// exists but every set is incomplete are dropped entirely (not
    /// zero-valued).
    func progressSeries(
        forExerciseId exerciseId: UUID,
        metric: ProgressMetric
    ) -> [(date: Date, value: Double)] {
        var points: [(Date, Double)] = []
        for workout in completedWorkouts {
            guard let exercise = workout.workout.exercises.first(where: { $0.id == exerciseId }) else {
                continue
            }
            let completedSets = exercise.sets.filter { $0.completed }
            guard !completedSets.isEmpty else { continue }
            let value: Double
            switch metric {
            case .weight:
                value = Double(completedSets.map { $0.weight }.max() ?? 0)
            case .reps:
                value = Double(completedSets.map { $0.reps }.max() ?? 0)
            }
            points.append((workout.dateCompleted, value))
        }
        return points
            .sorted(by: { $0.0 < $1.0 })
            .map { (date: $0.0, value: $0.1) }
    }

    /// The completed set with the highest weight ever logged for this
    /// exercise. Tied weights — first encountered wins. Returns nil if
    /// no completed sets exist anywhere across history.
    func weightPR(forExerciseId exerciseId: UUID) -> (weight: Float, reps: Int)? {
        var best: (weight: Float, reps: Int)? = nil
        for workout in completedWorkouts {
            guard let exercise = workout.workout.exercises.first(where: { $0.id == exerciseId }) else {
                continue
            }
            for set in exercise.sets where set.completed {
                if best == nil || set.weight > best!.weight {
                    best = (set.weight, set.reps)
                }
            }
        }
        return best
    }

    /// The completed set with the highest rep count ever logged for this
    /// exercise. Same tie-breaking + nil semantics as `weightPR`.
    func repsPR(forExerciseId exerciseId: UUID) -> (weight: Float, reps: Int)? {
        var best: (weight: Float, reps: Int)? = nil
        for workout in completedWorkouts {
            guard let exercise = workout.workout.exercises.first(where: { $0.id == exerciseId }) else {
                continue
            }
            for set in exercise.sets where set.completed {
                if best == nil || set.reps > best!.reps {
                    best = (set.weight, set.reps)
                }
            }
        }
        return best
    }
}


