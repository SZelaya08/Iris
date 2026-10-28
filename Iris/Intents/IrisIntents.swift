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

// MARK: - Frases de Siri
// Un solo atajo: Siri te pregunta qué decirle a Iris y ella hace el resto
// (crear tareas o recordatorios, marcarlos como hechos, decirte tus pendientes…).
// Las frases en español están aquí; las de inglés, en AppShortcuts.xcstrings.
// Se evitan "dile a…", "anota…", "nueva tarea…" porque Siri las manda a Mensajes, Notas o Recordatorios.

struct IrisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HablarConIrisIntent(),
            phrases: [
                "Hola \(.applicationName)",
                "Oye \(.applicationName)",
                "Mi asistente \(.applicationName)",
                "Asistente \(.applicationName)",
                "Conversar con \(.applicationName)",
                "\(.applicationName) escucha"
            ],
            shortTitle: "Hablar con Iris",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
    }
}
