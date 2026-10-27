import SwiftUI
import UserNotifications

@main
struct IrisApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var tasks = TaskStore()
    @StateObject private var reminders = ReminderStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(tasks)
                .environmentObject(reminders)
                .tint(IrisColor.navy)
        }
    }
}

/// Permite que las notificaciones también se vean cuando la app está abierta.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        SummaryNotification.schedule()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
