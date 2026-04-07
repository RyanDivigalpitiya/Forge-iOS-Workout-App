import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        // Suppress rest-timer notifications while the app is active.
        if notification.request.content.categoryIdentifier == "workoutCategory" {
            completionHandler([])
            return
        }

        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("Notification received: \(response.notification.request.content.title)")
        completionHandler()
    }
}
