import HealthKit
import WatchKit

/// Handles watch-level lifecycle callbacks that SwiftUI's `App` struct does not
/// receive directly, including workout launches initiated by the paired iPhone.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("[ForgeWatch] Received workout launch from iPhone")
        WatchWorkoutRuntime.shared.startWorkout(with: workoutConfiguration)
    }
}
