import Foundation
import EventKit
import WidgetKit

struct TaskGroup: Identifiable {
    let name: String
    let items: [TaskItem]
    var id: String { name }
}

/// Las tareas de la app. Se guardan en la lista "Iris" de Recordatorios
/// y avisan al widget cada vez que cambian.
@MainActor
final class TaskStore: ObservableObject {
    enum Access { case unknown, granted, denied }

    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var access: Access = .unknown

    private let repo = TaskRepository()
    private var observer: NSObjectProtocol?

    init() {
        access = TaskRepository.hasAccess ? .granted : (TaskRepository.wasDenied ? .denied : .unknown)

        // Si cambias algo desde la app Recordatorios, Iris se actualiza sola.
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: repo.store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reload() }
        }

        Task { await reload() }
    }

    var pendingCount: Int { tasks.filter { !$0.isDone }.count }

    // MARK: - Permiso

    func requestAccess() async {
        let granted = await repo.requestAccess()
        access = granted ? .granted : .denied
        if granted {
            _ = repo.irisList(create: true)
            migrateOldTasks()
            await reload()
        }
    }

    // MARK: - Acciones

    func reload() async {
        guard TaskRepository.hasAccess else {
            tasks = []
            return
        }
        access = .granted
        tasks = await repo.fetchTasks()
        WidgetCenter.shared.reloadAllTimelines()
        await LiveActivityManager.sync(tasks: tasks)
    }

    func add(title: String, dueDate: Date?) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        repo.add(title: clean, dueDate: dueDate)
        Task { await reload() }
    }

    func toggle(_ task: TaskItem) {
        // Se marca al instante en pantalla y luego se guarda.
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i].isDone.toggle()
        }
        repo.setDone(id: task.id, done: !task.isDone)
        Task { await reload() }
    }

    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        repo.delete(id: task.id)
        Task { await reload() }
    }

    func clearDone() {
        for task in tasks where task.isDone {
            repo.delete(id: task.id)
        }
        tasks.removeAll { $0.isDone }
        Task { await reload() }
    }

    // MARK: - Grupos

    /// Agrupa las tareas como en el diseño: Hoy, Esta semana, Más adelante y Sin fecha.
    var groups: [TaskGroup] {
        let cal = Calendar.current
        let now = Date()
        let endOfToday = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: now)) ?? now

        var hoy: [TaskItem] = []
        var semana: [TaskItem] = []
        var despues: [TaskItem] = []
        var sinFecha: [TaskItem] = []

        for t in tasks {
            guard let due = t.dueDate else { sinFecha.append(t); continue }
            if due < endOfToday { hoy.append(t) }
            else if due < endOfWeek { semana.append(t) }
            else { despues.append(t) }
        }

        let result = [
            TaskGroup(name: "Hoy", items: hoy),
            TaskGroup(name: "Esta semana", items: semana),
            TaskGroup(name: "Más adelante", items: despues),
            TaskGroup(name: "Sin fecha", items: sinFecha)
        ]
        return result
            .filter { !$0.items.isEmpty }
            .map { TaskGroup(name: $0.name, items: $0.items.sorted(by: TaskItem.sortOrder)) }
    }

    // MARK: - Tareas de la versión anterior

    /// La versión 0.1 guardaba las tareas dentro de la app. Las pasamos
    /// a la lista "Iris" una sola vez para que no se pierdan.
    private func migrateOldTasks() {
        struct OldTask: Codable {
            var title: String
            var dueDate: Date?
            var isDone: Bool
        }
        let key = "iris.tasks"
        let places = [UserDefaults(suiteName: "group.com.taliana.iris"), UserDefaults.standard]
        for case let defaults? in places {
            guard let data = defaults.data(forKey: key),
                  let old = try? JSONDecoder().decode([OldTask].self, from: data)
            else { continue }
            for task in old where !task.isDone {
                repo.add(title: task.title, dueDate: task.dueDate)
            }
            defaults.removeObject(forKey: key)
        }
    }
}
