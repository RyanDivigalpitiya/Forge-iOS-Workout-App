import HealthKit

class WorkoutHealthManager: ObservableObject {

    let healthStore = HKHealthStore()
    private var workoutSession: Any?  // HKWorkoutSession (iOS 26+), stored as Any for backward compat
    private var workoutBuilder: Any?  // HKLiveWorkoutBuilder (iOS 26+)

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToShare: Swift.Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Swift.Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error {
                print("[Forge] HealthKit authorization error: \(error)")
            }
        }
    }

    // MARK: - Live Workout Session (iOS 26+)

    func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if #available(iOS 26.0, *) {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .functionalStrengthTraining
            do {
                let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                workoutSession = session
                workoutBuilder = builder
                session.startActivity(with: Date())
                builder.beginCollection(withStart: Date()) { _, _ in }
            } catch {
                print("[Forge] Failed to start workout session: \(error)")
            }
        }
    }

    func endWorkoutSession(completion: @escaping (Double?) -> Void = { _ in }) {
        if #available(iOS 26.0, *) {
            guard let session = workoutSession as? HKWorkoutSession,
                  let builder = workoutBuilder as? HKLiveWorkoutBuilder else {
                completion(nil)
                return
            }
            session.end()
            builder.endCollection(withEnd: Date()) { [weak self] _, _ in
                builder.finishWorkout { workout, error in
                    if let error {
                        print("[Forge] HealthKit finish error: \(error)")
                    }
                    let stats = workout?.statistics(for: HKQuantityType(.activeEnergyBurned))
                    let calories = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    print("[Forge] HealthKit workout: \(workout != nil ? "present" : "nil"), stats: \(stats != nil ? "present" : "nil"), calories: \(calories as Any)")
                    DispatchQueue.main.async {
                        self?.workoutSession = nil
                        self?.workoutBuilder = nil
                        completion(calories)
                    }
                }
            }
        } else {
            completion(nil)
            workoutSession = nil
            workoutBuilder = nil
        }
    }

    /// Whether a live session is active (used to skip the manual save path)
    var hasActiveSession: Bool { workoutSession != nil }

    // MARK: - Manual Workout Save (fallback for iOS < 26 or when session fails)

    func saveWorkout(startDate: Date, endDate: Date, elapsedTime: TimeInterval) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        builder.beginCollection(withStart: startDate) { success, error in
            guard success else {
                if let error { print("[Forge] HealthKit begin collection error: \(error)") }
                return
            }
            builder.endCollection(withEnd: endDate) { success, error in
                guard success else {
                    if let error { print("[Forge] HealthKit end collection error: \(error)") }
                    return
                }
                builder.finishWorkout { workout, error in
                    if let error {
                        print("[Forge] HealthKit save error: \(error)")
                    }
                }
            }
        }
    }
}
