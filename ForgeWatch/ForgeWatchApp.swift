import SwiftUI

@main
struct ForgeWatchApp: App {

    init() {
        WatchSessionManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            BreakTimerWatchView()
                .environmentObject(WatchSessionManager.shared)
                .environment(\.colorScheme, .dark)
        }
    }
}
