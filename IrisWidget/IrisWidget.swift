import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

// MARK: - Opciones del widget
// Se cambian manteniendo presionado el widget › "Editar widget".

struct TasksWidgetOptions: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Tareas de Iris"
    static var description = IntentDescription("Elige qué muestra el widget.")

    @Parameter(title: "Mostrar las tareas", default: true)
    var showTasks: Bool

    @Parameter(title: "Tareas a mostrar", default: 3, inclusiveRange: (1, 3))
    var count: Int

    @Parameter(title: "Ocultar las terminadas", default: true)
    var hideDone: Bool
}

// MARK: - Datos

struct TasksEntry: TimelineEntry {
    enum Status { case ready, noAccess }

    let date: Date
    let tasks: [TaskItem]
    let pending: Int
    let showTasks: Bool
    let state: Status
}

struct TasksProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(
            date: Date(),
            tasks: [
                TaskItem(title: "Terminar el taller"),
                TaskItem(title: "Comprar los materiales"),
                TaskItem(title: "Estudiar para el parcial")
            ],
            pending: 3,
            showTasks: true,
            state: .ready
        )
    }

    func snapshot(for configuration: TasksWidgetOptions, in context: Context) async -> TasksEntry {
        let entry = await makeEntry(configuration)
        // En la galería mostramos un ejemplo si todavía no hay tareas.
        if context.isPreview && entry.tasks.isEmpty { return placeholder(in: context) }
        return entry
    }

    func timeline(for configuration: TasksWidgetOptions, in context: Context) async -> Timeline<TasksEntry> {
        // La app pide actualizar el widget cuando cambian las tareas;
        // además se refresca solo cada 15 minutos (por si cambias algo en Recordatorios).
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [await makeEntry(configuration)], policy: .after(next))
    }

    private func makeEntry(_ options: TasksWidgetOptions) async -> TasksEntry {
        guard TaskRepository.hasAccess else {
            return TasksEntry(date: Date(), tasks: [], pending: 0, showTasks: options.showTasks, state: .noAccess)
        }
        let all = await TaskRepository().fetchTasks().sorted(by: TaskItem.sortOrder)
        let visible = options.hideDone ? all.filter { !$0.isDone } : all
        return TasksEntry(
            date: Date(),
            tasks: Array(visible.prefix(min(3, max(1, options.count)))),
            pending: all.filter { !$0.isDone }.count,
            showTasks: options.showTasks,
            state: .ready
        )
    }
}

// MARK: - Vistas

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TasksEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryInline:
                Text(entry.state == .noAccess ? "Abre Iris" : "\(entry.pending) tareas pendientes")
            default:
                rectangular
            }
        }
        .containerBackground(for: .widget) {
            if family != .accessoryInline {
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
                if entry.state == .ready {
                    Text("\(entry.pending)")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            if entry.state == .noAccess {
                Text("Abre Iris para dar permiso")
                    .font(.system(size: 12))
            } else if !entry.showTasks {
                Text(entry.pending == 1 ? "1 pendiente" : "\(entry.pending) pendientes")
                    .font(.system(size: 12))
            } else if entry.tasks.isEmpty {
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
            Text(entry.state == .noAccess ? "–" : "\(entry.pending)")
                .font(.system(size: 18, weight: .semibold))
        }
    }
}

// MARK: - Configuración

struct TasksWidget: Widget {
    let kind = "IrisTasks"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TasksWidgetOptions.self, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Tareas de Iris")
        .description("Tus tareas pendientes en la pantalla de bloqueo.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Tarjeta grande (Actividad en vivo)

struct IrisTasksLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IrisTasksAttributes.self) { context in
            LockScreenTasksCard(state: context.state)
                .activityBackgroundTint(IrisColor.navy.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "iris://tareas"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        FlowerMark(lineWidth: 1.4, color: IrisColor.powder)
                            .frame(width: 20, height: 20)
                        Text("Iris")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(pendingText(context.state.pending))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(IrisColor.powder)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TaskChipsGrid(tasks: Array(context.state.tasks.prefix(6)))
                        .padding(.top, 4)
                }
            } compactLeading: {
                FlowerMark(lineWidth: 1.4, color: IrisColor.powder)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text("\(context.state.pending)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IrisColor.powder)
            } minimal: {
                Text("\(context.state.pending)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IrisColor.powder)
            }
            .widgetURL(URL(string: "iris://tareas"))
        }
    }
}

private func pendingText(_ n: Int) -> String {
    n == 1 ? "1 pendiente" : "\(n) pendientes"
}

/// La tarjeta en la pantalla de bloqueo: encabezado con la flor y las tareas en dos columnas.
struct LockScreenTasksCard: View {
    let state: IrisTasksAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    FlowerMark(lineWidth: 1.4, color: .white)
                        .frame(width: 18, height: 18)
                    Text("Iris")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.16)))
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))

                Spacer()

                Text(pendingText(state.pending))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(IrisColor.powder)
            }

            if state.tasks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Todo listo por hoy")
                }
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                TaskChipsGrid(tasks: state.tasks)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
    }
}

/// Las tareas como "pastillas" de cristal. Se acomodan según cuántas haya:
/// - 1 a 3 tareas: una sola columna, cada tarea a lo ancho.
/// - 4 a 6 tareas: dos columnas; si quedan impares, la última va a lo ancho.
/// La tarjeta crece o se encoge con las tareas, así que nunca quedan huecos.
struct TaskChipsGrid: View {
    let tasks: [String]

    /// iOS limita la tarjeta a 160 puntos de alto: con 3 filas (5 o 6 tareas)
    /// las burbujas se hacen un poco más compactas para que nada se corte.
    private var compact: Bool { tasks.count >= 5 || tasks.count == 3 }

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            if tasks.count <= 3 {
                ForEach(Array(tasks.enumerated()), id: \.offset) { _, title in
                    TaskChip(title: title, size: tasks.count == 1 ? .large : (compact ? .compact : .regular))
                }
            } else {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        ForEach(Array(rows[i].enumerated()), id: \.offset) { _, title in
                            TaskChip(title: title, size: compact ? .compact : .regular)
                        }
                    }
                }
            }
        }
    }

    /// Agrupa las tareas de a dos: [[1, 2], [3, 4], [5]].
    private var rows: [[String]] {
        stride(from: 0, to: tasks.count, by: 2).map { start in
            Array(tasks[start..<min(start + 2, tasks.count)])
        }
    }
}

struct TaskChip: View {
    enum Size { case large, regular, compact }

    let title: String
    let size: Size

    private var fontSize: CGFloat {
        switch size { case .large: 16; case .regular: 14; case .compact: 13 }
    }
    private var verticalPadding: CGFloat {
        switch size { case .large: 10; case .regular: 8; case .compact: 5 }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: size == .large ? 10 : 8, height: size == .large ? 10 : 8)
            Text(title)
                .font(.system(size: fontSize, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Capsule().fill(Color.white.opacity(0.14)))
        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
    }
}

@main
struct IrisWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
        IrisTasksLiveActivity()
    }
}
