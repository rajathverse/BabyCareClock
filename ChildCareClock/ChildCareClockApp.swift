import SwiftUI
import UserNotifications

@main
struct ChildCareClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AppPreferences.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Handles notification actions, including Done and Snooze tapped while the app is closed.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()
        // Created early so background launches (Siri, Live Activity buttons, the Watch) are handled.
        _ = CareViewModel.shared
        WatchSync.shared.activate()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let idString = response.notification.request.content.userInfo[NotificationScheduler.itemKey] as? String
        Task { @MainActor in
            if let idString, let id = UUID(uuidString: idString) {
                switch action {
                case NotificationScheduler.doneAction:
                    CareViewModel.shared.complete(id)
                case NotificationScheduler.snoozeAction:
                    CareViewModel.shared.snooze(id)
                default:
                    break
                }
            }
            completionHandler()
        }
    }
}
