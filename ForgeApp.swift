import SwiftUI

@main
struct ForgeApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                // Handle error here.
                print("Error requesting notifications authorization: \(error)")
            }
            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            CompletedWorkoutsView()
                .environmentObject(CompletedWorkoutsViewModel())
                .environmentObject(PlanViewModel())
                .environmentObject(ExerciseViewModel())
                .environment(\.colorScheme, .dark)
        }
    }
}
