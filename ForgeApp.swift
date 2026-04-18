import SwiftUI

@main
struct ForgeApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var healthManager = WorkoutHealthManager()
    @StateObject private var planViewModel = PlanViewModel()

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

        PhoneSessionManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            CompletedWorkoutsView()
                .environmentObject(CompletedWorkoutsViewModel())
                .environmentObject(planViewModel)
                .environmentObject(ExerciseViewModel())
                .environmentObject(healthManager)
                .environmentObject(GlobalSettings.shared)
                .environment(\.colorScheme, .dark)
                .onAppear {
                    healthManager.requestAuthorization()
                }
                .onOpenURL { url in
                    importIncomingPlan(from: url)
                }
        }
    }

    private func importIncomingPlan(from url: URL) {
        guard url.pathExtension.lowercased() == "forgeplan" else { return }
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard
            let data = try? Data(contentsOf: url),
            let plan = try? JSONDecoder().decode(WorkoutPlan.self, from: data)
        else {
            print("Failed to decode shared plan at \(url.lastPathComponent)")
            return
        }
        planViewModel.importPlan(plan)
    }
}
