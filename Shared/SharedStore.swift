import Foundation
import WidgetKit

/// Datos que comparten la app y el widget de la pantalla de bloqueo.
/// Se guardan en el "App Group", un espacio que ambos pueden leer.
enum AppGroup {
    static let id = "group.com.taliana.iris"

    /// Si el App Group no está disponible (por ejemplo, por cómo se firmó la app),
    /// usamos el almacenamiento normal para que la app siga funcionando.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date? = nil
    var isDone: Bool = false
    var createdAt: Date = Date()

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

struct WidgetSettings: Codable, Equatable {
    var enabled: Bool = true
    var count: Int = 3
    var hideDone: Bool = true
}

enum SharedStore {
    private static let tasksKey = "iris.tasks"
    private static let widgetKey = "iris.widgetSettings"

    static func loadTasks() -> [TaskItem] {
        guard let data = AppGroup.defaults.data(forKey: tasksKey),
              let items = try? JSONDecoder().decode([TaskItem].self, from: data)
        else { return [] }
        return items
    }

    static func saveTasks(_ items: [TaskItem]) {
        if let data = try? JSONEncoder().encode(items) {
            AppGroup.defaults.set(data, forKey: tasksKey)
        }
        reloadWidgets()
    }

    static func loadWidgetSettings() -> WidgetSettings {
        guard let data = AppGroup.defaults.data(forKey: widgetKey),
              let settings = try? JSONDecoder().decode(WidgetSettings.self, from: data)
        else { return WidgetSettings() }
        return settings
    }

    static func saveWidgetSettings(_ settings: WidgetSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            AppGroup.defaults.set(data, forKey: widgetKey)
        }
        reloadWidgets()
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
