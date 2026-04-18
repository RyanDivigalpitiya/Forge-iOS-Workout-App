import Foundation
import HealthKit

/// Owns an HKWorkoutSession on the watch for the lifetime of a Forge workout.
/// The session keeps the watch app running (no background suspension), which
/// allows the break timer's TimelineView + onChange to fire the expiry haptic
/// the moment it hits zero.
///
/// iOS launches the watch app via `HKHealthStore.startWatchApp(with:)`, and the
/// watch app delegate forwards that workout configuration here immediately.
/// A later WCSession `workoutStarted` message is still accepted as a fallback.
final class WatchWorkoutRuntime: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, ObservableObject {

    static let shared = WatchWorkoutRuntime()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published private(set) var isActive: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Swift.Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Swift.Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { success, error in
            if let error {
                print("[ForgeWatch] HK auth error: \(error.localizedDescription)")
            } else {
                print("[ForgeWatch] HK auth success: \(success)")
            }
        }
    }

    // MARK: - Lifecycle

    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor
        startWorkout(with: configuration)
    }

    func startWorkout(with configuration: HKWorkoutConfiguration) {
        guard session == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[ForgeWatch] HealthKit unavailable — cannot start workout session")
            return
        }

        do {
            let s = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            s.delegate = self
            b.delegate = self

            s.startActivity(with: Date())
            b.beginCollection(withStart: Date()) { success, error in
                if let error {
                    print("[ForgeWatch] Builder beginCollection error: \(error.localizedDescription)")
                }
            }

            session = s
            builder = b
            isActive = true
            print("[ForgeWatch] HKWorkoutSession started")
        } catch {
            print("[ForgeWatch] Failed to start HKWorkoutSession: \(error.localizedDescription)")
        }
    }

    func endWorkout() {
        guard let s = session, let b = builder else { return }
        s.end()
        b.endCollection(withEnd: Date()) { _, _ in
            b.finishWorkout { _, _ in }
        }
        session = nil
        builder = nil
        isActive = false
        print("[ForgeWatch] HKWorkoutSession ended")
    }

    // MARK: - HKWorkoutSessionDelegate

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("[ForgeWatch] Workout session error: \(error.localizedDescription)")
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Swift.Set<HKSampleType>) {}
}
