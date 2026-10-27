import AppIntents
import Foundation

// MARK: - "Oye Siri, dile a Iris…"

/// Le pasa a Iris (la IA) lo que dices y Siri te lee su respuesta.
struct HablarConIrisIntent: AppIntent {
    static var title: LocalizedStringResource = "Hablar con Iris"
    static var description = IntentDescription("Dile algo a Iris: crea tareas, recordatorios o pregúntale por tu día.")
    static var openAppWhenRun = false

    @Parameter(title: "Mensaje", requestValueDialog: IntentDialog("¿Qué le digo a Iris?"))
    var mensaje: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tasks = TaskStore()
        let reminders = ReminderStore()
        await tasks.reload()

        // Lo que hablas con Siri también queda en el chat de Iris.
        var history = ChatHistory.load()
        history.append(ChatMessage(fromIris: false, text: mensaje))

        let agent = IrisAgent(tasks: tasks, reminders: reminders)
        let answer: String
        do {
            let reply = try await agent.respond(history: history)
            history.append(ChatMessage(fromIris: true, text: reply.text, actions: reply.actions))
            answer = reply.text
        } catch {
            answer = error.localizedDescription
            history.append(ChatMessage(fromIris: true, text: answer))
        }
        ChatHistory.save(history)
        await tasks.reload()
        return .result(dialog: "\(answer)")
    }
}

// MARK: - "Oye Siri, agrega una tarea en Iris"

/// Agrega una tarea directamente, sin pasar por la IA (es lo más rápido).
struct AgregarTareaIntent: AppIntent {
    static var title: LocalizedStringResource = "Agregar tarea en Iris"
    static var description = IntentDescription("Agrega una tarea a tu lista de Iris.")
    static var openAppWhenRun = false

    @Parameter(title: "Tarea", requestValueDialog: IntentDialog("¿Qué tarea agrego?"))
    var tarea: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TaskRepository.hasAccess else {
            return .result(dialog: "Primero abre Iris y dale permiso para usar Recordatorios.")
        }
        let store = TaskStore()
        let title = tarea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return .result(dialog: "No escuché la tarea. Inténtalo de nuevo.")
        }
        store.add(title: title, dueDate: nil)
        await store.reload()
        return .result(dialog: "Listo, agregué «\(title)» a tus tareas.")
    }
}

// MARK: - "Oye Siri, ¿qué tengo pendiente en Iris?"

/// Siri te lee tus tareas pendientes.
struct PendientesIntent: AppIntent {
    static var title: LocalizedStringResource = "Tareas pendientes de Iris"
    static var description = IntentDescription("Escucha tus tareas pendientes.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TaskRepository.hasAccess else {
            return .result(dialog: "Primero abre Iris y dale permiso para usar Recordatorios.")
        }
        let store = TaskStore()
        await store.reload()
        let pending = store.tasks.filter { !$0.isDone }.sorted(by: TaskItem.sortOrder)

        guard !pending.isEmpty else {
            return .result(dialog: "No tienes tareas pendientes. ¡Todo listo!")
        }

        let names = pending.prefix(5).map(\.title)
        let list: String
        if names.count == 1 {
            list = names[0]
        } else {
            list = names.dropLast().joined(separator: ", ") + " y " + (names.last ?? "")
        }
        let intro = pending.count == 1 ? "Tienes una tarea pendiente" : "Tienes \(pending.count) tareas pendientes"
        let extra = pending.count > 5 ? ". Te leí las 5 más urgentes." : "."
        return .result(dialog: "\(intro): \(list)\(extra)")
    }
}

// MARK: - Frases de Siri
// Las frases en inglés están aquí; las de español están en AppShortcuts.xcstrings.

struct IrisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HablarConIrisIntent(),
            phrases: [
                "Tell \(.applicationName)",
                "Talk to \(.applicationName)",
                "Ask \(.applicationName)"
            ],
            shortTitle: "Hablar con Iris",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: AgregarTareaIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Nueva tarea",
            systemImageName: "checkmark.square"
        )
        AppShortcut(
            intent: PendientesIntent(),
            phrases: [
                "What's pending in \(.applicationName)",
                "My tasks in \(.applicationName)"
            ],
            shortTitle: "Pendientes",
            systemImageName: "list.bullet"
        )
    }
}
