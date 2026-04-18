import SwiftUI
import WatchKit

@main
struct ForgeWatchApp: App {

    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate

    init() {
        WatchSessionManager.shared.activateSession()
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
