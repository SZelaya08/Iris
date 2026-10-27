import Foundation
import UserNotifications

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Una sola vez"
        case .daily: return "Todos los días"
        case .weekly: return "Cada semana"
        case .monthly: return "Cada mes"
        case .yearly: return "Cada año"
        }
    }
}

struct ReminderItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var repeatRule: RepeatRule = .none

    var repeats: Bool { repeatRule != .none }

    /// El disparador de la notificación según cada cuánto se repite.
    var trigger: UNCalendarNotificationTrigger {
        let components: Set<Calendar.Component>
        switch repeatRule {
        case .none: components = [.year, .month, .day, .hour, .minute]
        case .daily: components = [.hour, .minute]
        case .weekly: components = [.weekday, .hour, .minute]
        case .monthly: components = [.day, .hour, .minute]
        case .yearly: components = [.month, .day, .hour, .minute]
        }
        let match = Calendar.current.dateComponents(components, from: date)
        return UNCalendarNotificationTrigger(dateMatching: match, repeats: repeats)
    }

    var nextDate: Date? { trigger.nextTriggerDate() }

    /// Texto como "El 5 de cada mes · 9:00 a. m."
    var whenText: String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let es = Locale(identifier: "es_CO")
        switch repeatRule {
        case .none:
            let day = date.formatted(.dateTime.day().month(.wide).locale(es))
            return "\(day) · \(time)"
        case .daily:
            return "Todos los días · \(time)"
        case .weekly:
            let weekday = date.formatted(.dateTime.weekday(.wide).locale(es))
            return "Cada \(weekday) · \(time)"
        case .monthly:
            let day = Calendar.current.component(.day, from: date)
            return "El \(day) de cada mes · \(time)"
        case .yearly:
            let day = date.formatted(.dateTime.day().month(.wide).locale(es))
            return "Cada \(day) · \(time)"
        }
    }

    /// Texto como "En 10 días".
    var remainingText: String {
        guard let next = nextDate else { return "Ya pasó" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.unitsStyle = .full
        let text = f.localizedString(for: next, relativeTo: Date())
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// Guarda los recordatorios y programa sus notificaciones en el iPhone.
@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var reminders: [ReminderItem] = []
    @Published var notificationsDenied = false

    private let key = "iris.reminders"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
            reminders = items
        }
    }

    var repeating: [ReminderItem] {
        reminders.filter { $0.repeats }.sorted { ($0.nextDate ?? .distantFuture) < ($1.nextDate ?? .distantFuture) }
    }

    var oneTime: [ReminderItem] {
        reminders.filter { !$0.repeats }.sorted { $0.date < $1.date }
    }

    func add(_ reminder: ReminderItem) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notificationsDenied = !granted

        reminders.append(reminder)
        save()

        let content = UNMutableNotificationContent()
        content.title = "Iris"
        content.body = reminder.title
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: reminder.trigger
        )
        try? await center.add(request)
    }

    func delete(_ reminder: ReminderItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        reminders.removeAll { $0.id == reminder.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
