import Foundation
import UserNotifications

/// Aviso diario a la hora del resumen. El resumen lo escribe Iris al abrir la app.
enum SummaryNotification {
    private static let id = "iris.resumen"

    static func schedule() {
        let defaults = UserDefaults.standard
        let active = defaults.object(forKey: "iris.resumenActivo") as? Bool ?? true
        let seconds = defaults.object(forKey: "iris.resumenHora") as? Double ?? 6.5 * 3600
        let nombre = defaults.string(forKey: "iris.nombre") ?? ""

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard active else { return }

        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Iris"
            content.body = nombre.isEmpty
                ? "Buenos días. Tu resumen de hoy está listo."
                : "Buenos días, \(nombre). Tu resumen de hoy está listo."
            content.sound = .default
            let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(seconds)
            let parts = Calendar.current.dateComponents([.hour, .minute], from: start)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
