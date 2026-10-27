import Foundation

struct TaskGroup: Identifiable {
    let name: String
    let items: [TaskItem]
    var id: String { name }
}

/// Guarda las tareas y avisa al widget cada vez que cambian.
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []

    init() {
        tasks = SharedStore.loadTasks()
    }

    var pendingCount: Int { tasks.filter { !$0.isDone }.count }

    func add(title: String, dueDate: Date?) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        tasks.append(TaskItem(title: clean, dueDate: dueDate))
        save()
    }

    func toggle(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isDone.toggle()
        save()
    }

    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func clearDone() {
        tasks.removeAll { $0.isDone }
        save()
    }

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

    private func save() {
        SharedStore.saveTasks(tasks)
    }
}
