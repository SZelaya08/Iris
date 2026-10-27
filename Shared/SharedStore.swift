import Foundation
import WidgetKit

/// Datos que comparten la app y el widget de la pantalla de bloqueo.
/// Se guardan en el "App Group", un espacio que ambos pueden leer.
enum AppGroup {
    /// El nombre con el que se creó el proyecto.
    static let defaultID = "group.com.taliana.iris"

    /// Al instalar con un Apple ID gratuito, Sideloadly le pone otro nombre al grupo.
    /// Por eso lo leemos del perfil de instalación que viene dentro de la app
    /// (la app y el widget tienen cada uno el suyo, con el mismo grupo).
    static let id: String = {
        let groups = groupsFromProvisioningProfile()
        return groups.first(where: { $0.localizedCaseInsensitiveContains("iris") })
            ?? groups.first
            ?? defaultID
    }()

    /// true si el sistema realmente le dio a esta app acceso al grupo compartido.
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    /// Lee los grupos permitidos del archivo embedded.mobileprovision.
    static func groupsFromProvisioningProfile() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>", range: start.lowerBound..<raw.endIndex),
              let plistData = String(raw[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups.filter { !$0.contains("*") }
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

    /// Si había tareas guardadas con el nombre anterior del grupo, las pasa al nuevo
    /// para que no se pierdan al actualizar la app.
    static func migrateIfNeeded() {
        guard AppGroup.id != AppGroup.defaultID,
              AppGroup.defaults.data(forKey: tasksKey) == nil,
              let old = UserDefaults(suiteName: AppGroup.defaultID)
        else { return }
        if let tasks = old.data(forKey: tasksKey) {
            AppGroup.defaults.set(tasks, forKey: tasksKey)
        }
        if let settings = old.data(forKey: widgetKey) {
            AppGroup.defaults.set(settings, forKey: widgetKey)
        }
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
