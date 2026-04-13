import HealthKit

class WorkoutHealthManager: ObservableObject {

    let healthStore = HKHealthStore()

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToShare: Swift.Set<HKSampleType> = [HKObjectType.workoutType()]
        healthStore.requestAuthorization(toShare: typesToShare, read: []) { success, error in
            if let error {
                print("[Forge] HealthKit authorization error: \(error)")
            }
        }
    }

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
