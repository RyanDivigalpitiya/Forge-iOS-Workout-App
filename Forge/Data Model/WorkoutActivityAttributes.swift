import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    // Static — set when the activity is created, never changes
    let planName: String

    struct ContentState: Codable, Hashable {
        let percentCompleted: Int
        let isResting: Bool
        let restEndDate: Date?        // non-nil when resting; used with Text(timerInterval:)
        let nextExerciseName: String?
        let nextSetDescription: String? // e.g. "100 lb × 12 reps"
    }
}
