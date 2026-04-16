import SwiftUI
import UserNotifications

@main
struct ForgeWatchApp: App {

    init() {
        WatchSessionManager.shared.activateSession()
        UNUserNotificationCenter.current().delegate = WatchSessionManager.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[ForgeWatch] Notification auth error: \(error.localizedDescription)")
            }
            print("[ForgeWatch] Notification auth granted: \(granted)")
        }
        WatchWorkoutRuntime.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            BreakTimerWatchView()
                .environmentObject(WatchSessionManager.shared)
                .environment(\.colorScheme, .dark)
        }
    }
}
