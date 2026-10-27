import WidgetKit
import SwiftUI

// MARK: - Datos del widget

struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let pending: Int
    let settings: WidgetSettings
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(
            date: Date(),
            tasks: [
                TaskItem(title: "Terminar el taller"),
                TaskItem(title: "Comprar los materiales"),
                TaskItem(title: "Estudiar para el parcial")
            ],
            pending: 3,
            settings: WidgetSettings()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        let entry = makeEntry()
        // En la galería de widgets mostramos un ejemplo si todavía no hay tareas.
        completion(context.isPreview && entry.tasks.isEmpty ? placeholder(in: context) : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        // La app pide actualizar el widget cada vez que cambian las tareas;
        // además se refresca solo cada 30 minutos.
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }

    private func makeEntry() -> TasksEntry {
        let settings = SharedStore.loadWidgetSettings()
        let all = SharedStore.loadTasks().sorted(by: TaskItem.sortOrder)
        let visible = settings.hideDone ? all.filter { !$0.isDone } : all
        return TasksEntry(
            date: Date(),
            tasks: Array(visible.prefix(max(1, settings.count))),
            pending: all.filter { !$0.isDone }.count,
            settings: settings
        )
    }
}

// MARK: - Vistas

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TasksEntry

    var body: some View {
        Group {
            if !entry.settings.enabled {
                // Desactivado desde Ajustes: el widget queda vacío.
                Color.clear
            } else {
                switch family {
                case .accessoryCircular:
                    circular
                case .accessoryInline:
                    Text("\(entry.pending) tareas pendientes")
                default:
                    rectangular
                }
            }
        }
        .containerBackground(for: .widget) {
            if entry.settings.enabled && family != .accessoryInline {
                AccessoryWidgetBackground()
            }
        }
        .widgetURL(URL(string: "iris://tareas"))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                FlowerMark(lineWidth: 1.2, color: .primary)
                    .frame(width: 12, height: 12)
                Text("Tareas")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text("\(entry.pending)")
                    .font(.system(size: 12, weight: .semibold))
            }
            if entry.tasks.isEmpty {
                Text("Todo listo")
                    .font(.system(size: 12))
            } else {
                ForEach(entry.tasks) { task in
                    HStack(spacing: 5) {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 9, weight: .semibold))
                        Text(task.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .strikethrough(task.isDone)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var circular: some View {
        VStack(spacing: 1) {
            FlowerMark(lineWidth: 1.2, color: .primary)
                .frame(width: 16, height: 16)
            Text("\(entry.pending)")
                .font(.system(size: 18, weight: .semibold))
        }
    }
}

// MARK: - Configuración

struct TasksWidget: Widget {
    let kind = "IrisTasks"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Tareas de Iris")
        .description("Tus tareas pendientes en la pantalla de bloqueo.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct IrisWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
    }
}
