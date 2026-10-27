import Foundation
import EventKit
import CoreGraphics

/// Una tarea de Iris. Se guarda como un recordatorio dentro de la lista "Iris"
/// de la app Recordatorios de Apple, así el widget también la puede leer.
struct TaskItem: Identifiable, Hashable {
    var id: String
    var title: String
    var dueDate: Date? = nil
    var isDone: Bool = false
    var createdAt: Date = Date()

    init(id: String = UUID().uuidString, title: String, dueDate: Date? = nil, isDone: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.createdAt = createdAt
    }

    init(reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? ""
        self.dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        self.isDone = reminder.isCompleted
        self.createdAt = reminder.creationDate ?? .distantPast
    }

    /// Orden para la lista y el widget: pendientes primero, luego por fecha.
    static func sortOrder(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.isDone != b.isDone { return !a.isDone }
        switch (a.dueDate, b.dueDate) {
        case let (da?, db?): return da < db
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return a.createdAt < b.createdAt
        }
    }
}

/// Lee y escribe las tareas en la lista "Iris" de Recordatorios.
/// La usan la app y el widget, cada uno con su propia copia.
final class TaskRepository {
    static let listName = "Iris"

    let store = EKEventStore()

    // MARK: - Permiso

    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    static var wasDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return status == .denied || status == .restricted || status == .writeOnly
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    // MARK: - La lista "Iris"

    /// Busca la lista "Iris". Si no existe y `create` es true, la crea (solo la app lo hace).
    func irisList(create: Bool) -> EKCalendar? {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == Self.listName }) {
            return existing
        }
        guard create else { return nil }

        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = Self.listName
        list.cgColor = CGColor(srgbRed: 0x1E / 255.0, green: 0x35 / 255.0, blue: 0x57 / 255.0, alpha: 1)

        let candidates = [store.defaultCalendarForNewReminders()?.source]
            + store.sources.filter { $0.sourceType == .calDAV }.map { Optional($0) }
            + store.sources.filter { $0.sourceType == .local }.map { Optional($0) }

        for case let source? in candidates {
            list.source = source
            if (try? store.saveCalendar(list, commit: true)) != nil {
                return list
            }
        }
        return nil
    }

    // MARK: - Leer

    func fetchTasks() async -> [TaskItem] {
        guard Self.hasAccess, let list = irisList(create: false) else { return [] }
        let predicate = store.predicateForReminders(in: [list])
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).map(TaskItem.init(reminder:))
                continuation.resume(returning: items)
            }
        }
    }

    // MARK: - Escribir

    @discardableResult
    func add(title: String, dueDate: Date?) -> Bool {
        guard let list = irisList(create: true) else { return false }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueDate
            )
        }
        return (try? store.save(reminder, commit: true)) != nil
    }

    func setDone(id: String, done: Bool) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = done
        try? store.save(reminder, commit: true)
    }

    func delete(id: String) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        try? store.remove(reminder, commit: true)
    }
}
