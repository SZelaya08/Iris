import Foundation
import ActivityKit

/// Enciende, actualiza o apaga la tarjeta grande de tareas.
@MainActor
enum LiveActivityManager {
    static let settingKey = "iris.liveActivity"
    static let maxTasks = 6

    static var isOn: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    static var systemAllows: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Pone la tarjeta al día con las tareas pendientes.
    /// iOS solo deja crearla con la app abierta, así que se llama al abrir Iris
    /// y cada vez que cambian las tareas.
    static func sync(tasks: [TaskItem]) async {
        guard isOn else {
            await endAll()
            return
        }
        guard systemAllows else { return }

        let pending = tasks.filter { !$0.isDone }.sorted(by: TaskItem.sortOrder)
        let state = IrisTasksAttributes.ContentState(
            tasks: pending.prefix(maxTasks).map(\.title),
            pending: pending.count
        )
        let content = ActivityContent(state: state, staleDate: nil)

        let activities = Activity<IrisTasksAttributes>.activities
        if let current = activities.first(where: { $0.activityState == .active }) {
            await current.update(content)
            // Por si quedó alguna repetida.
            for other in activities where other.id != current.id {
                await other.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        // La anterior se venció (iOS las cierra después de unas horas): creamos una nueva.
        await endAll()
        _ = try? Activity<IrisTasksAttributes>.request(
            attributes: IrisTasksAttributes(),
            content: content,
            pushType: nil
        )
    }

    static func endAll() async {
        for activity in Activity<IrisTasksAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
